# Glicemia (API)

Stack Swarm `infra-app-glicemia` para a API Laravel do monorepo
`lucaskaiut/glicemia` (subpasta `api/`). O frontend (`web/`) está na Vercel
(projeto `glicemia`) em `https://glicosimetro.noxtecnologias.com.br`.

- Hostname: `glicosimetro-api.noxtecnologias.com.br` (TLS via Traefik/Let's Encrypt).
- Serviços: `app` (2 réplicas, nginx + php-fpm), `worker` (fila database) e `scheduler`.
- Banco: MySQL compartilhado (`infra_shared`, host `mysql`), base `glicemia`.
- Volume `glicemia_storage` em `storage/app`.
- Auth: Sanctum SPA (cookie) com `SESSION_DOMAIN=.noxtecnologias.com.br`; o leitor
  Windows usa tokens de API (`api_…`) com escopo `glucose.import`.
- Contas independentes (cadastro gratuito); o seed de demonstração **não** roda em produção.
- Dados de saúde: sem logs de payload; acesso só pela própria conta.

## Deploy

```bash
cd ~/infra
./ci/deploy-app.sh glicemia
```

Jenkins: job `deploy-glicemia-webhook` (push em `main` com mudanças em `api/`).
Credencial do webhook: `glicemia-webhook-token`.

## Banco (uma vez)

```sql
CREATE DATABASE IF NOT EXISTS glicemia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'glicemia'@'%' IDENTIFIED BY '<senha>';
GRANT ALL PRIVILEGES ON glicemia.* TO 'glicemia'@'%';
FLUSH PRIVILEGES;
```

As migrations correm no arranque do serviço `app`.
