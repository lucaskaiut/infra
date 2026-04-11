# Etapa 4 — API eMatricula (Laravel 13)

## Objetivo

Executar a API em `https://ematricula-api.lucaskaiut.com.br` com **MySQL e Redis partilhados** (`stacks/shared/`), filas via **Horizon** e **scheduler** Laravel.

## Requisitos

- Traefik + rede `infra_edge`.
- **Stack `stacks/shared/`** a correr (MySQL + Redis, rede `infra_shared`). Ver `docs/05-servicos-compartilhados.md`.
- DNS `ematricula-api.lucaskaiut.com.br` → VPS.
- Clone do monorepo em `stacks/apps/ematricula/ematricula/` (a imagem Docker usa `ematricula/api`).

## Configuração

### 1. Shared (`stacks/shared/`)

```bash
cd ~/infra/stacks/shared
cp .env.example .env
```

Defina `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER` e `MYSQL_PASSWORD` (valores que a app eMatricula usará como `DB_DATABASE`, `DB_USERNAME` e `DB_PASSWORD`).

```bash
docker compose --env-file .env up -d
```

### 2. eMatricula (`stacks/apps/ematricula/`)

```bash
cp .env.example .env
```

- `APP_KEY`, `APP_URL`, etc.
- **`DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD`** iguais a **`MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD`** do shared.
- `DB_HOST=mysql`, `REDIS_HOST=redis`, `REDIS_PREFIX=ematricula_` (recomendado no Redis partilhado).

## Deploy

```bash
cd ~/infra/stacks/apps/ematricula
git clone https://github.com/lucaskaiut/ematricula.git ematricula
cp .env.example .env
# editar .env (alinhado ao shared)
docker compose build
docker compose up -d
```

## Validação

- `curl -sS -o /dev/null -w '%{http_code}' https://ematricula-api.lucaskaiut.com.br/` → **200**
- `curl -sS https://ematricula-api.lucaskaiut.com.br/up` → health
- `docker compose -f ~/infra/stacks/shared/docker-compose.yml --project-directory ~/infra/stacks/shared ps` → MySQL e Redis **running**
- `docker compose ps` na pasta ematricula → `app`, `horizon`, `scheduler` **running**
- OpenAPI em `/docs`; endpoints `/api/*` conforme `public/openapi.yaml`

## Atualizar a API

```bash
cd ~/infra/stacks/apps/ematricula/ematricula && git pull
cd .. && docker compose build && docker compose up -d
```

## Notas

- A imagem apenas **constrói e executa** o código em `ematricula/api` tal como está no repositório da aplicação. **Correções de código Laravel** são feitas no repositório **ematricula**, não na infra.
- Comportamento incorreto da API deve ser corrigido **na aplicação**.
- A primeira subida do `app` corre `php artisan migrate --force` contra o MySQL em `mysql` (shared).
- **HTTPS e assets (Vite):** o Nginx da imagem da app define `fastcgi_param HTTPS on` e `HTTP_X_FORWARDED_PROTO https` (TLS no Traefik).
- O dashboard Horizon em `/horizon` está protegido pelo gate da aplicação; o processo **horizon** processa jobs independentemente da UI.
