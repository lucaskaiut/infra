# Minha Rotina (API)

Stack Swarm `infra-app-minha-rotina` para a API Laravel do monorepo
`lucaskaiut/minha-rotina` (subpasta `api/`).

- Hostname: `minharotina-api.noxtecnologias.com.br` (TLS via Traefik/Let's Encrypt).
- Serviços: `app` (2 réplicas, nginx + php-fpm), `worker` (fila database) e
  `scheduler` (lembretes e fechamento do dia).
- Banco: MySQL compartilhado (`infra_shared`, host `mysql`).
- Cache/fila: `database` (sem dependência de Redis).
- Web Push: chaves VAPID no `.env` (`php artisan rotina:vapid-keys`).

## Deploy

```bash
cd ~/infra
./ci/deploy-app.sh minha-rotina
```

O Jenkins usa o job `deploy-minha-rotina-webhook` (push em `main` com mudanças
em `api/`). Webhooks: ver `docs/arquitetura.md` secção 12.

## Banco

Criar base/usuário no MySQL compartilhado (uma vez):

```sql
CREATE DATABASE IF NOT EXISTS minha_rotina CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'minha_rotina'@'%' IDENTIFIED BY '<senha>';
GRANT ALL PRIVILEGES ON minha_rotina.* TO 'minha_rotina'@'%';
FLUSH PRIVILEGES;
```

As migrations correm no arranque do serviço `app`.
