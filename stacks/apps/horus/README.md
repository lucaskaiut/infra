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

## Jenkins — deploy automático (push em `api/`)

Pipeline no repo **infra**: `ci/jenkins/DeployHorusWebhook.Jenkinsfile`. Em pushes para **`main`** no GitHub **`lucaskaiut/horus`**, só corre `./ci/deploy-app.sh horus` se os commits tocarem em **`api/`** (ou em build manual do job).

### 1. Credencial no Jenkins

Gera um segredo seguro (ex.: `openssl rand -hex 32`) e usa **o mesmo valor** na credencial abaixo e no parâmetro `token=` da URL do GitHub.

| Campo | Valor |
|--------|--------|
| Tipo | **Secret text** |
| **ID** (obrigatório, literal) | `horus-webhook-token` |
| Secret | String longa aleatória (ex.: `openssl rand -hex 32`) |

O valor **não** vai para o Git: define-o só no Jenkins (e replica **exactamente** na query string do webhook GitHub abaixo).

### 2. Criar o job `deploy-horus-webhook` na VPS

Com o Jenkins a correr (`infra_jenkins`) e já existindo um job webhook modelo (ex.: **deploy-ematricula-webhook**):

```bash
cd ~/infra
git pull origin main
./ci/jenkins/create-webhook-job-from-template.sh \
  deploy-ematricula-webhook \
  deploy-horus-webhook \
  ci/jenkins/DeployHorusWebhook.Jenkinsfile \
  horus-webhook-token \
  horus
```

Alternativa em Jenkins novo (volume CasC/init): executar o seed `ci/jenkins/seed-deploy-horus-webhook-job.groovy` conforme o fluxo dos outros jobs (requer credencial **`horus-webhook-token`** criada **antes** do primeiro POST do GitHub).

### 3. URL do webhook no GitHub

No repositório da app (**Settings → Webhooks → Add webhook**):

| Campo | Valor |
|--------|--------|
| **Payload URL** | `https://jenkins.<TEU_DOMÍNIO>/generic-webhook-trigger/invoke?token=`**`SEGREDO`** |
| **Content type** | `application/json` |
| **SSL verification** | Enable (recomendado) |
| **Which events** | **Just the push events** |

Substitua `<TEU_DOMÍNIO>` pelo mesmo domínio público do Jenkins (ex.: o `DOMAIN` onde responde `https://jenkins.<DOMAIN>`). O parâmetro **`token=`** deve ser **igual byte-a-byte** ao secret guardado na credencial **`horus-webhook-token`**.

**Exemplo** (domínio ilustrativo — o segredo é fictício):

```text
https://jenkins.exemplo.com/generic-webhook-trigger/invoke?token=a1b2c3d4e5f6789...
```

**Nota:** `JENKINS_URL` em `stacks/jenkins/.env` deve ser HTTPS público alinhado a este host; ver `docs/arquitetura.md` (secção Jenkins / webhooks).
