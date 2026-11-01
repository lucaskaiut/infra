# Nox Tasks (API)

Stack Swarm `infra-app-nox-tasks` para a API Laravel do monorepo
`lucaskaiut/nox-tasks` (subpasta `api/`). O frontend (`web/`) está na Vercel
(projeto `nox-tasks`) em `https://tasks.noxtecnologias.com.br`.

- Hostname: `tasks-api.noxtecnologias.com.br` (TLS via Traefik/Let's Encrypt).
- Serviços: `app` (2 réplicas, nginx + php-fpm), `worker` (fila database) e
  `scheduler` (faturas/assinaturas).
- Banco: MySQL compartilhado (`infra_shared`, host `mysql`), base `nox_tasks`.
- Arquivos (anexos/uploads): volume `nox_tasks_storage` em `storage/app`.
- Auth: Sanctum SPA (cookie) com `SESSION_DOMAIN=.noxtecnologias.com.br`.

## Deploy

```bash
cd ~/infra
./ci/deploy-app.sh nox-tasks
```

O Jenkins usa o job `deploy-nox-tasks-webhook` (push em `main` com mudanças
em `api/`). Credencial do webhook: `nox-tasks-webhook-token`.

## Banco

Criar base/usuário no MySQL compartilhado (uma vez):

```sql
CREATE DATABASE IF NOT EXISTS nox_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nox_tasks'@'%' IDENTIFIED BY '<senha>';
GRANT ALL PRIVILEGES ON nox_tasks.* TO 'nox_tasks'@'%';
FLUSH PRIVILEGES;
```

As migrations correm no arranque do serviço `app`. Os seeders de demonstração
**não** são executados em produção; o tenant raiz tem `domain=tasks.noxtecnologias.com.br`
(resolução de tenant por `Referer` no login).
