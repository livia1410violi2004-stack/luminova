# Publicar o LumiNova no GitHub + Netlify (com API no Render)

O Netlify publica a interface estática e o Supabase gerencia autenticação e dados. O cadastro/login do frontend usam Supabase Auth diretamente; o trigger existente deve criar o perfil na tabela. O backend Python/SQLite incluído é legado e não é usado pelo formulário de autenticação atualizado.

## Antes de publicar

1. Revise o projeto e remova arquivos pessoais/segredos. O banco local `backend/luminova.db` é ignorado pelo `.gitignore`; não o publique.
2. Abra `supabase-config.js` e preencha `url` com a Project URL e `anonKey` com a chave publicável/anon do Supabase (Settings → API). Nunca use a `service_role key` no navegador.
3. Crie um repositório no GitHub e envie a pasta `luminova_edit` (ou o conteúdo dela na raiz).
4. No Netlify, importe o repositório. Se a pasta `luminova_edit` estiver dentro do repositório, defina Base directory como `luminova_edit`; se o conteúdo estiver na raiz, deixe vazio. Publish directory: `.`.
5. No Supabase, em Authentication → URL Configuration, adicione o domínio Netlify em Site URL/Redirect URLs, por exemplo `https://seu-projeto.netlify.app/**`. Ajuste também os templates de e-mail se necessário.
6. Publique e teste cadastro, confirmação de e-mail, login e recuperação de senha no domínio Netlify. Confirme que o trigger cria exatamente um perfil na tabela existente.

## Atenção

- O código mantém as demais telas; esta alteração troca especificamente o fluxo de cadastro/login para Supabase Auth. Outras funcionalidades podem ainda depender de APIs próprias ou dados locais e precisam ser testadas separadamente.
- Se o Supabase exigir confirmação de e-mail, o usuário verá uma mensagem para confirmar antes de entrar.
- Confirme as políticas RLS das tabelas: nunca desative RLS para “fazer funcionar”.
- Não publique senhas, tokens privados ou a chave `service_role`. A chave pública/anon é apropriada para o frontend quando as políticas RLS estão corretas.
- O login aceita e-mail; login por apelido requer uma consulta segura à tabela de perfis e não foi presumido porque o nome/estrutura da tabela não foi fornecido.
