# LUMINOVA — atualização de comunidades sociais

## O que esta versão adiciona
- Banner da comunidade usando a capa escolhida e avatar.
- Publicações dentro da comunidade com upload de fotos e vídeos.
- Respostas/comentários nas publicações.
- Chat geral da comunidade e chat separado para cada subcomunidade.
- Criação de subcomunidades para proprietários/moderadores.
- Chat atualiza com Supabase Realtime quando a tabela está na publicação `supabase_realtime`.
- A sessão do navegador usa `sessionStorage`; o código não usa `localStorage`.

## Instalação
1. Faça backup dos arquivos atuais.
2. No Supabase, abra SQL Editor e crie uma consulta chamada `LUMINOVA - Comunidades Sociais`.
3. Cole o conteúdo completo de `luminova-comunidades-social.sql` e execute uma vez.
4. Publique os arquivos de `app/frontend` no mesmo projeto Netlify. Preserve as credenciais corretas de `supabase-config.js`.
5. Atualize o site com Ctrl+F5 e teste com uma conta que seja membro ativo da comunidade.

## Importante
- Upload de mídia exige que o bucket `community-media` exista e que as políticas de Storage permitam upload na pasta iniciada pelo ID do usuário.
- O chat e as subcomunidades exigem que a migração SQL acima seja executada.
- Subcomunidades podem ser criadas por proprietários/moderadores. Chat e publicação exigem membro ativo.
- JavaScript foi validado sintaticamente, mas esta entrega não foi conectada ao seu projeto Supabase real; teste permissões e upload no seu ambiente.
