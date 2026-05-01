# Stack Horus (API Laravel apenas)

Publica só a pasta `api` do repositório [horus](https://github.com/lucaskaiut/horus), conforme a secção *Publicação em produção* do README upstream: MySQL, Redis, OpenSearch 2.x, worker da fila `logs`, API PHP 8.4 atrás do Traefik.

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** (`stacks/shared/`) com MySQL e Redis na rede `infra_shared`.
- Na MySQL partilhada: criar a base **`horus`** (ou o nome em `DB_DATABASE`) e garantir que o utilizador tem permissões (`GRANT … ON horus.*`).
- DNS **`A`** para `horus-api.<DOMAIN>` → IP da VPS (`DOMAIN` alinhado ao `.env` desta stack e ao `.env` da raiz do infra).
- Docker com build habilitado.

## Primeira vez: clonar o monorepo

Na pasta desta stack (`stacks/apps/horus`):

```bash
git clone https://github.com/lucaskaiut/horus.git horus
```

Atualizações:

```bash
cd horus && git pull && cd ..
```

## Variáveis de ambiente

```bash
cp .env.example .env
```

- Gere **`APP_KEY`** (ex.: noutro ambiente `php artisan key:generate --show`).
- **`DB_*`** coerentes com o utilizador MySQL na stack shared (`DB_HOST=mysql`).
- **`REDIS_*`** com `REDIS_HOST=redis`; **`REDIS_PREFIX=horus_`** evita colisões no Redis partilhado.
- **`OPENSEARCH_URL=http://opensearch:9200`** — serviço interno desta stack (sem porta exposta no host).
- **`QUEUE_CONNECTION=redis`**, **`CACHE_STORE=redis`**, **`SESSION_DRIVER=redis`** alinhados com as recomendações do README da app.
- **`SANCTUM_STATEFUL_DOMAINS`** com o hostname público da API (`horus-api.<DOMAIN>`).

## Subir

Com **Docker Swarm** (padrão do repo):

```bash
cd ~/infra && ./ci/deploy-app.sh horus
```

Isto clona/atualiza `horus/`, faz **build** de `local/horus-api:latest` e faz **`docker stack deploy`** (`infra-app-horus`). O OpenSearch corre apenas na rede interna `infra_horus_internal`.

Sem Swarm: `APP_USE_SWARM=0 ./ci/deploy-app.sh horus` ou `docker compose build && docker compose up -d` nesta pasta.

## Serviços nesta stack

| Serviço      | Função                                      |
|-------------|---------------------------------------------|
| `app`       | Nginx + PHP-FPM, TLS via Traefik, health `/up` |
| `worker`    | `queue:work redis --queue=logs`             |
| `opensearch`| Índices `logs-*` (volume persistente)     |

MySQL e Redis estão em **`stacks/shared/`**.

## Notas de segurança (OpenSearch)

O compose usa `plugins.security.disabled=true` num nó interno à rede Docker — adequado para tráfego só entre containers. Para modelo com TLS e credenciais (recomendado pelo README upstream para cenários mais expostos), será preciso outra imagem/configuração e **`OPENSEARCH_URL`** com autenticação.
