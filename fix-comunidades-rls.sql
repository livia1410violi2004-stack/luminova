-- LUMINOVA — correção segura das políticas RLS de comunidades.
-- Execute UMA vez no Supabase > SQL Editor > New query > Run.
-- A política de leitura de communities não consulta community_members;
-- isso evita a recursão infinita que pode bloquear a listagem.

begin;

-- Remove políticas antigas/desconhecidas destas duas tabelas para que uma
-- política permissiva antiga não continue causando recursão por OR.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('communities', 'community_members')
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

alter table public.communities enable row level security;
alter table public.community_members enable row level security;

-- Comunidades públicas podem ser descobertas sem login. Donos também podem
-- consultar as próprias comunidades privadas/ocultas. Não consultar membros aqui.
create policy communities_read_public_or_owner
on public.communities for select to anon, authenticated
using (visibility = 'public' or owner_id = (select auth.uid()));

create policy communities_insert_owner
on public.communities for insert to authenticated
with check (owner_id = (select auth.uid()));

create policy communities_update_owner
on public.communities for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy communities_delete_owner
on public.communities for delete to authenticated
using (owner_id = (select auth.uid()));

-- Membros podem ver a própria participação. Para os demais casos, a consulta
-- a communities é segura porque a política acima não consulta community_members.
create policy community_members_read_self_or_visible_community
on public.community_members for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.communities c
    where c.id = community_members.community_id
      and (c.visibility = 'public' or c.owner_id = (select auth.uid()))
  )
);

create policy community_members_join_self
on public.community_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'member'
  and status in ('active', 'pending')
);

create policy community_members_leave_self
on public.community_members for delete to authenticated
using (user_id = (select auth.uid()));

create policy community_members_update_owner
on public.community_members for update to authenticated
using (
  exists (select 1 from public.communities c
          where c.id = community_members.community_id
            and c.owner_id = (select auth.uid()))
)
with check (
  exists (select 1 from public.communities c
          where c.id = community_members.community_id
            and c.owner_id = (select auth.uid()))
);

grant select on public.communities to anon, authenticated;
grant insert, update, delete on public.communities to authenticated;
grant select, insert, update, delete on public.community_members to authenticated;

commit;

-- Diagnóstico rápido depois de executar:
-- select id, name, visibility, created_at from public.communities
-- where visibility = 'public' order by created_at desc;
