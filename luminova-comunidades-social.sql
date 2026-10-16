-- LUMINOVA: subcomunidades e chat por comunidade/subcomunidade.
-- Execute no SQL Editor do Supabase uma vez, depois de aplicar o schema principal.
-- Não usa localStorage e não apaga dados existentes.

create extension if not exists pgcrypto;

create or replace function public.luminova_is_active_community_member(target_community uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.community_members m
    where m.community_id = target_community
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.luminova_can_manage_community(target_community uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.communities c
    where c.id = target_community and c.owner_id = auth.uid()
  ) or exists (
    select 1 from public.community_members m
    where m.community_id = target_community
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role in ('owner','moderator')
  ) or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;


create or replace function public.luminova_can_view_community(target_community uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.communities c
    where c.id = target_community
      and (c.visibility = 'public' or c.owner_id = auth.uid()
        or exists (select 1 from public.community_members m
          where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active'))
  );
$$;

create or replace function public.luminova_subcommunity_matches(target_subcommunity uuid, target_community uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.community_subcommunities s
    where s.id = target_subcommunity and s.community_id = target_community);
$$;

grant execute on function public.luminova_is_active_community_member(uuid) to anon, authenticated;
grant execute on function public.luminova_can_view_community(uuid) to anon, authenticated;
grant execute on function public.luminova_subcommunity_matches(uuid, uuid) to authenticated;
grant execute on function public.luminova_can_manage_community(uuid) to authenticated;

create table if not exists public.community_subcommunities (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  description text not null default '' check (char_length(description) <= 500),
  cover_url text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists community_subcommunities_parent_idx
  on public.community_subcommunities(community_id, created_at desc);

create table if not exists public.community_chat_messages (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  subcommunity_id uuid references public.community_subcommunities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 5000),
  media_url text,
  media_type text check (media_type is null or media_type in ('image','video')),
  created_at timestamptz not null default now(),
  constraint community_chat_message_has_content check (char_length(trim(content)) > 0 or media_url is not null)
);
create index if not exists community_chat_messages_room_idx
  on public.community_chat_messages(community_id, subcommunity_id, created_at);

alter table public.community_subcommunities enable row level security;
alter table public.community_chat_messages enable row level security;

drop policy if exists luminova_subcommunities_read on public.community_subcommunities;
create policy luminova_subcommunities_read
on public.community_subcommunities for select to anon, authenticated
using (public.luminova_can_view_community(community_id));

drop policy if exists luminova_subcommunities_create on public.community_subcommunities;
create policy luminova_subcommunities_create
on public.community_subcommunities for insert to authenticated
with check (
  created_by = auth.uid()
  and public.luminova_can_manage_community(community_id)
);

drop policy if exists luminova_subcommunities_update on public.community_subcommunities;
create policy luminova_subcommunities_update
on public.community_subcommunities for update to authenticated
using (public.luminova_can_manage_community(community_id))
with check (public.luminova_can_manage_community(community_id));

drop policy if exists luminova_subcommunities_delete on public.community_subcommunities;
create policy luminova_subcommunities_delete
on public.community_subcommunities for delete to authenticated
using (public.luminova_can_manage_community(community_id));

drop policy if exists luminova_chat_read on public.community_chat_messages;
create policy luminova_chat_read
on public.community_chat_messages for select to authenticated
using (public.luminova_is_active_community_member(community_id));

drop policy if exists luminova_chat_send on public.community_chat_messages;
create policy luminova_chat_send
on public.community_chat_messages for insert to authenticated
with check (
  user_id = auth.uid()
  and public.luminova_is_active_community_member(community_id)
  and (subcommunity_id is null or public.luminova_subcommunity_matches(subcommunity_id, community_id))
);

grant select, insert, update, delete on public.community_subcommunities to authenticated;
grant select, insert on public.community_chat_messages to authenticated;
grant select on public.community_subcommunities to anon;

-- Os arquivos de chat usam o bucket community-media já criado na migração anterior.
-- O upload continua restrito à pasta iniciada pelo ID do usuário autenticado.

-- Ativa eventos Realtime para o chat. Se já estiver publicada, não é problema.
do $$
begin
  alter publication supabase_realtime add table public.community_chat_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
