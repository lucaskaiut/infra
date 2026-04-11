# Stack eMatricula (API Laravel)

Publica apenas a pasta `api` do repositório [ematricula](https://github.com/lucaskaiut/ematricula).

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** (`stacks/shared/`) com MySQL e Redis na rede `infra_shared`. Ver `docs/05-servicos-compartilhados.md`.
- DNS `A` para `ematricula-api.lucaskaiut.com.br` → IP da VPS.
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
- **`DB_PASSWORD` tem de ser igual a `EMATRICULA_DB_PASSWORD`** definido em `stacks/shared/.env`.
- `DB_HOST=mysql` e `REDIS_HOST=redis` resolvem para os serviços partilhados.
- `REDIS_PREFIX=ematricula_` reduz colisões com outras apps no mesmo Redis.

## Subir

```bash
docker compose build
docker compose up -d
```

## Serviços **nesta** stack

| Serviço     | Função                          |
|------------|----------------------------------|
| `app`      | Nginx + PHP-FPM, API + TLS       |
| `horizon`  | Worker de filas (Laravel Horizon)|
| `scheduler`| `schedule:run` a cada 60 s      |

MySQL e Redis estão em **`stacks/shared/`**, não aqui.

Documentação detalhada: `docs/04-etapa-4-ematricula-api.md`.
