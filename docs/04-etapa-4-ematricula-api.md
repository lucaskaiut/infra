# Etapa 4 — API eMatricula (Laravel 13)

## Objetivo

Executar a API em `https://ematricula-api.lucaskaiut.com.br` com MySQL, Redis, filas via **Horizon** e **scheduler** Laravel.

## Requisitos

- Traefik + rede `infra_edge`.
- DNS `ematricula-api.lucaskaiut.com.br` → VPS.
- Clone do monorepo em `stacks/apps/ematricula/ematricula/` (a imagem Docker usa `ematricula/api`).

## Configuração

1. `cp stacks/apps/ematricula/.env.example stacks/apps/ematricula/.env`
2. Definir `APP_KEY` (ex.: `php artisan key:generate --show` com o código local, ou gerar bytes aleatórios conforme README da stack).
3. Definir `DB_PASSWORD` e `MYSQL_ROOT_PASSWORD` fortes e coerentes com `DB_USERNAME` / `DB_DATABASE`.

Variáveis críticas já previstas no `.env.example`:

- `DB_HOST=mysql`, `REDIS_HOST=redis`
- `QUEUE_CONNECTION=redis`, `CACHE_STORE=redis`
- `TELESCOPE_ENABLED=false` em produção

## Deploy

```bash
cd ~/infra/stacks/apps/ematricula
git clone https://github.com/lucaskaiut/ematricula.git ematricula
cp .env.example .env
# editar .env
docker compose build
docker compose up -d
```

## Validação

- `curl -sS -o /dev/null -w '%{http_code}' https://ematricula-api.lucaskaiut.com.br/` → **200**
- `curl -sS https://ematricula-api.lucaskaiut.com.br/up` → resposta de health
- `docker compose ps` → `mysql`, `redis`, `app`, `horizon`, `scheduler` **running**
- OpenAPI em `/docs` (rota web da aplicação)
- Endpoints `/api/*` conforme `public/openapi.yaml` (muitos exigem autenticação Sanctum)

## Atualizar a API

```bash
cd ~/infra/stacks/apps/ematricula/ematricula && git pull
cd .. && docker compose build && docker compose up -d
```

## Notas

- A primeira subida do `app` corre `php artisan migrate --force`.
- O dashboard Horizon em `/horizon` está protegido pelo gate da aplicação; o processo **horizon** processa jobs independentemente da UI.
- Se `URL` gerada incorretamente atrás do proxy, pode ser necessário confiar em proxies no projeto Laravel (`TrustProxies` / `trustProxies` no bootstrap) numa alteração futura do repositório da app.
