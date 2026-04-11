# Stack eMatricula (API Laravel)

Publica apenas a pasta `api` do repositório [ematricula](https://github.com/lucaskaiut/ematricula).

## Pré-requisitos na VPS

- Stack `edge` (Traefik) a correr com rede `infra_edge`.
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

Gere `APP_KEY` (pode ser no host com PHP ou noutro container Laravel):

```bash
openssl rand -base64 32
```

Coloque o resultado em `.env` como `APP_KEY=base64:...` (o Laravel espera o prefixo `base64:` quando aplicável — use `php artisan key:generate --show` num ambiente com o projeto se preferir).

Altere `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD` e quaisquer segredos reais.

## Subir

```bash
docker compose build --no-cache
docker compose up -d
```

## Serviços

| Serviço     | Função                          |
|------------|----------------------------------|
| `app`      | Nginx + PHP-FPM, API + TLS       |
| `mysql`    | MySQL 8.4                        |
| `redis`    | Redis 7 (cache, filas, Horizon)  |
| `horizon`  | Worker de filas (Laravel Horizon)|
| `scheduler`| `schedule:run` a cada 60 s      |

Documentação detalhada: `docs/04-etapa-4-ematricula-api.md`.
