# NutriFlow (API)

Stack Swarm `infra-app-nutriflow` para a API Laravel do monorepo
`lucaskaiut/nutriflow` (subpasta `api/`). O app é mobile (Expo) e fala com a API por tokens Bearer.

- Hostname: `nutriflow-api.noxtecnologias.com.br` (registro A DNS-only no Cloudflare; TLS via Traefik/Let's Encrypt).
- Serviço único `app` (nginx + php-fpm). A API não usa fila nem agendador (`QUEUE_CONNECTION=sync`).
- Banco: MySQL compartilhado (`infra_shared`, host `mysql`), base `nutriflow`.
- Volume `nutriflow_storage` em `storage/app` (fotos de receitas no disco privado).
- No arranque: `migrate --force` + seeders idempotentes da base TACO (categorias e 597 alimentos).
  A conta demo **não** é criada em produção.
- Dados de saúde: acesso só pela própria conta; logs em `warning`, sem payloads.
- Recuperação de senha: com `MAIL_MAILER=log` o código não é enviado; configurar SMTP para ativar.

## Deploy

```bash
cd ~/infra
./ci/deploy-app.sh nutriflow
```

## Banco (uma vez)

```sql
CREATE DATABASE IF NOT EXISTS nutriflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nutriflow'@'%' IDENTIFIED BY '<senha>';
GRANT ALL PRIVILEGES ON nutriflow.* TO 'nutriflow'@'%';
FLUSH PRIVILEGES;
```
