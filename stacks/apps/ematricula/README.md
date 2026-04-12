# Stack eMatricula (API Laravel)

Publica apenas a pasta `api` do repositório [ematricula](https://github.com/lucaskaiut/ematricula).

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** (`stacks/shared/`) com MySQL e Redis na rede `infra_shared`. Ver `docs/arquitetura.md` (secção *Stack shared*).
- DNS `A` para `ematricula-api.<DOMAIN>` → IP da VPS (o mesmo `DOMAIN` que definires no `.env` desta stack, alinhado à raiz do infra).
- Docker com build habilitado.

## Primeira vez: clonar o código da API

Na pasta desta stack (`stacks/apps/ematricula`):

```bash
git clone https://github.com/lucaskaiut/ematricula.git ematricula
```

Atualizações:

```bash
cd ematricula && git pull && cd ..
```

## Variáveis de ambiente

```bash
cp .env.example .env
```

- Gere `APP_KEY` (ex.: `php artisan key:generate --show` noutro ambiente ou ver doc da Etapa 4).
- **`DB_DATABASE`, `DB_USERNAME` e `DB_PASSWORD`** alinhados com **`MYSQL_DATABASE`, `MYSQL_USER` e `MYSQL_PASSWORD`** em `stacks/shared/.env`.
- `DB_HOST=mysql` e `REDIS_HOST=redis` resolvem para os serviços partilhados.
- `REDIS_PREFIX=ematricula_` reduz colisões com outras apps no mesmo Redis.

## Subir

```bash
docker compose build
docker compose up -d
```

Deploy ou atualização a partir da raiz do repo **infra** (recomendado):

```bash
cd ~/infra && ./ci/deploy-app.sh ematricula
```

Ver `docs/arquitetura.md` (secções *CI* e *Jenkins*).

## Serviços **nesta** stack

| Serviço     | Função                          |
|------------|----------------------------------|
| `app`      | Nginx + PHP-FPM, API + TLS       |
| `horizon`  | Worker de filas (Laravel Horizon)|
| `scheduler`| `schedule:run` a cada 60 s      |

MySQL e Redis estão em **`stacks/shared/`**, não aqui.

Documentação detalhada: `docs/arquitetura.md` (secção *Stack eMatricula*).
