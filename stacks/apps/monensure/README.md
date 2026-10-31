# Stack Monensure (API Laravel)

Publica apenas a pasta `api` do monorepo
[monensure](https://github.com/lucaskaiut/monensure). O frontend
(`web/`) é hospedado em outro lugar.

## Domínios

- API: `https://monensure-api.${DOMAIN}`
- Frontend: `https://monensure.${DOMAIN}` (construído fora desta stack)

`DOMAIN=noxtecnologias.com.br` no `.env` desta stack.

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** com MySQL na rede `infra_shared`.
- DNS `A` para `monensure-api.noxtecnologias.com.br` → IP da VPS.
- Base de dados `monensure` + usuário com privilégios no MySQL compartilhado.

## OAuth (MCP)

O servidor MCP financeiro (`/api/mcp/financial`) aceita OAuth 2.1 via
Laravel Passport para conectores remotos (claude.ai web/mobile/desktop).
As chaves ficam em `PASSPORT_PRIVATE_KEY` / `PASSPORT_PUBLIC_KEY` no `.env`
da stack (ver `.env.example`) — precisam ser idênticas nas réplicas, por isso
não são geradas no container. Trocar as chaves invalida todos os tokens OAuth.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh monensure
```

Faz build da imagem `local/monensure-api:latest` (PHP 8.4 + Nginx + PHP-FPM)
e deploy via Swarm na stack `infra-app-monensure`.

## Serviços desta stack

| Serviço | Função |
|---------|--------|
| `app`   | Nginx + PHP-FPM (API, TLS no Traefik), 2 réplicas, rolling `start-first` |
| `worker`| Fila (`queue:work` com driver database) |

MySQL fica em `stacks/shared/`, não aqui.
