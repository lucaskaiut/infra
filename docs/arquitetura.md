# Arquitetura e operação da infraestrutura

Documento único: visão da plataforma Docker na VPS, decisões técnicas, como subir e corrigir problemas. Público-alvo: equipa que mantém **infra** (repositório separado do código das aplicações).

---

## 1. Papel deste repositório

| Repositório | Conteúdo |
|-------------|----------|
| **infra** (este) | Traefik, redes overlay Swarm, MySQL/Redis partilhados, stacks Compose/Swarm por app, Jenkins, scripts `ci/`, documentação operacional |
| **Aplicações** (ex.: `alura`, `vulcano`, `chat-one`, `nox-cms`) | Código nas apps; imagens locais costumam construir-se a partir de `…/api` (ou `…/backend`) no monorepo |

---

## 2. Mapa de pastas

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Traefik (TLS, roteamento): `docker-stack.yml` (Swarm) + `docker-compose.yml` (legado) |
| `stacks/shared/` | MySQL + Redis: `docker-stack.yml` (Swarm) + `docker-compose.yml` (legado) |
| `stacks/apps/<slug>/` | `docker-compose.yml` (build local da imagem) + `docker-stack.yml` (deploy Swarm) |
| `stacks/apps/_template/` | Modelo para copiar ao criar nova app simples |
| `stacks/jenkins/` | Jenkins (CI/CD), imagem customizada, CasC, init Groovy, chaves de deploy (`keys-*/`) |
| `ci/` | `deploy-app.sh`, `ci/apps/<slug>.sh`, Jenkinsfiles em `ci/jenkins/`, `swarm-bootstrap.sh`, `http-probe-loop.sh`, notificação n8n |
| `scripts/` | Utilitários pontuais (ex.: criação de credencial Jenkins via API) |

---

## 3. Redes e nomenclatura

- **`infra_edge`** — Rede **overlay** (`docker network create -d overlay --attachable infra_edge`), partilhada por Traefik (stack Swarm), apps expostas ao Traefik e pelo **Jenkins** (Compose clássico, ligado à mesma rede).
- **`infra_shared`** — Rede **overlay** (`… infra_shared`) para MySQL, Redis e apps que precisam de BD/cache. Serviços noutras stacks Swarm na mesma rede resolvem **`mysql`** e **`redis`** pelo nome do serviço na stack `infra-shared`.
- **Swarm:** um nó manager na VPS (`docker swarm init`); stacks nomeadas `infra-edge`, `infra-shared`, `infra-netdata`, `infra-opensearch`, `infra-app-<slug>`.
- **Compose clássico:** mantido para **build** da imagem (`docker compose -f docker-compose.yml build`) e para **Jenkins** (limitação: `group_add` para o socket Docker **não** é suportado em `docker stack deploy`).
- **APIs Laravel (Swarm):** serviço `app` com **2 réplicas**, `deploy.update_config.order: start-first` e `parallelism: 1` — atualização rolling (nova tarefa sobe e passa a saudável antes de retirar a antiga).

**Regra:** um par MySQL + Redis para todas as apps; isolamento em Redis com **prefixos** (ex. Laravel `REDIS_PREFIX`). Apps com requisitos próprios (ex.: evolutionapi) sobem Postgres/Redis dedicados dentro da própria stack.

### 3.1 Bootstrap Swarm e redes (VPS)

Na **primeira** configuração (ou após migração a partir de redes bridge com o mesmo nome):

```bash
cd ~/infra
export SWARM_ADVERTISE_ADDR=<IP_da_VPS>
./ci/swarm-bootstrap.sh
```

O script ativa o Swarm se necessário e cria **`infra_edge`** e **`infra_shared`** como overlay **attachable**. Se uma rede com o mesmo nome já existir como **bridge**, o script falha com instruções: é preciso parar os contentores que a usam, remover a rede antiga e voltar a correr o bootstrap (ver secção *Migração Compose → Swarm*).

---

## 4. Decisões técnicas

| Área | Escolha | Motivo |
|------|---------|--------|
| Proxy / TLS | Traefik **v3.6** | Labels Docker, ACME; evita *client API 1.24 too old* com Docker Engine 29+ |
| Orquestração | **Docker Swarm** (stacks `infra-edge`, `infra-shared`, `infra-netdata`, `infra-opensearch`, apps) + Compose para build e Jenkins | Rolling update (`start-first`) nas APIs; uma VPS manager |
| ACME | `httpChallenge` (entrypoint `web`) | Configuração atual em `stacks/edge/traefik/static/traefik.yml`; o Traefik responde ao challenge na porta 80 antes do redirect global HTTP→HTTPS |
| Deploy por app | `ci/deploy-app.sh <slug>` + `ci/apps/<slug>.sh` | Configuração mínima por app; Jenkins na mesma VPS monta o clone **infra** e o **socket Docker** (sem SSH no pipeline de deploy) |
| Jenkins | Imagem `lts` customizada (`infra-jenkins`), CasC, init Groovy | job `ci-smoke` na primeira subida do volume |

**Traefik (segurança):** `exposedByDefault: false`; só entra no proxy quem tiver `traefik.enable=true`. Socket Docker no Traefik em **read-only**. Jenkins usa o socket **read-write** para `docker compose` — implica risco elevado se o Jenkins for comprometido; usar só em VPS dedicada, HTTPS forte e password admin forte.

---

## 5. Ordem de arranque na VPS

1. **`ci/swarm-bootstrap.sh`** — Swarm + redes overlay `infra_edge` e `infra_shared` (uma vez, ou após migração).
2. **shared (Swarm)** — `stacks/shared/docker-stack.yml` → stack **`infra-shared`** (MySQL e Redis).
3. **edge (Swarm)** — `stacks/edge/docker-stack.yml` → **`infra-edge`** (Traefik).
4. **apps (Swarm)** — ex.: `./ci/deploy-app.sh vulcano` (stack **`infra-app-vulcano`**); ver tabela da secção 10 para o método de deploy de cada app.
5. **jenkins (Compose)** — `docker compose up -d` em `stacks/jenkins/` (liga à rede **`infra_edge`** já existente).

Sem **shared** a correr, apps que dependem de MySQL/Redis falham ou ficam à espera.

---

## 6. Domínios e firewall

A infra serve **quatro domínios base**. O `DOMAIN` da raiz (`~/infra/.env`) é **`lucaskaiut.com.br`**; stacks com domínio próprio usam o seu `.env` local (ver secção 7).

### 6.1 Hostnames em produção (por domínio)

**`lucaskaiut.com.br`** (DOMAIN raiz):

| Hostname | Stack | Serviço |
|----------|-------|---------|
| `traefik.lucaskaiut.com.br` | `infra-edge` | Dashboard Traefik (Basic Auth) |
| `jenkins.lucaskaiut.com.br` | Jenkins (Compose) | CI/CD |
| `alura-api.lucaskaiut.com.br` | `infra-app-alura` | API Alura |
| `evolution.lucaskaiut.com.br` | `infra-app-evolutionapi` | Evolution API (WhatsApp) |
| `docs.lucaskaiut.com.br` | `infra-app-hedgedoc` | HedgeDoc |
| `n8n.lucaskaiut.com.br` | `infra-app-n8n` | n8n (automações) |
| `uptime.lucaskaiut.com.br` | `infra-app-uptime-kuma` | Uptime Kuma |
| `netdata.lucaskaiut.com.br` | `infra-netdata` | Monitorização Netdata |
| `opensearch.lucaskaiut.com.br` | `infra-opensearch` | OpenSearch |

**`noxtecnologias.com.br`**:

| Hostname | Stack | Serviço |
|----------|-------|---------|
| `chatone-api.noxtecnologias.com.br` | `infra-app-chat-one` | API ChatOne (+ `/app` → Reverb) |
| `cms-api.noxtecnologias.com.br` | `infra-app-nox-cms` | API nox-cms |

**`noxagenda.com.br`**:

| Hostname | Stack | Serviço |
|----------|-------|---------|
| `api.noxagenda.com.br` | `infra-app-nox-schduler` | API nox-schduler |

**`dborcath.com.br`**:

| Hostname | Stack | Serviço |
|----------|-------|---------|
| `sistema-api.dborcath.com.br` | `infra-app-vulcano` | API Vulcano |
| `financeiro-api.dborcath.com.br` | `infra-app-financeiro-borcath` | API Financeiro Borcath |

- Registos **`A`** por hostname (não há wildcard genérico aplicado).
- **UFW (exemplo):** `OpenSSH`, `80/tcp`, `443/tcp` permitidos.

---

## 7. Ficheiros `.env` e interpolação do Compose

- Na **raiz** do clone (`~/infra`): `DOMAIN`, `ACME_EMAIL`, `GITHUB_*`, `N8N_*`, etc. Usado por stacks que fazem `--env-file ../../.env` (ex.: **edge**).
- **`${DOMAIN}` nos labels Traefik** do YAML é resolvido pelo **Compose** a partir do ficheiro passado com `--env-file` (ou `.env` na pasta do projeto), **não** pelo `env_file:` interno do serviço (esse injeta variáveis **dentro** do container).
- **Atenção:** variáveis já exportadas no shell (ex.: `DOMAIN` vindo de `~/infra/.env` via `ci/deploy-app.sh`) **têm prioridade** sobre o `--env-file` da stack. O `deploy-app.sh` limpa do shell as chaves do `.env` da app antes do `docker compose config`, para stacks com domínio próprio (ex.: **chat-one** → `noxtecnologias.com.br`) não herdarem `lucaskaiut.com.br`.

**Boas práticas:**

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
docker compose --env-file ../../.env ps
```

**Atalho:** `ln -sf ../../.env .env` na pasta da stack para não repetir `--env-file`.

**Stacks com `.env` local** (todas têm `.env.example` versionado): `stacks/shared/`, `stacks/jenkins/`, `stacks/apps/<slug>/` (alura, atena, chat-one, ematricula, evolutionapi, financeiro-borcath, hedgedoc, horus, n8n, nox-cms, nox-schduler, opensearch, plutao, tasksautomation, toth, toth-ai, uptime-kuma, vulcano). **Exceção:** `stacks/apps/netdata/` — o `docker-stack.yml` fixa o hostname (`netdata.lucaskaiut.com.br`) e não usa `.env`.

---

## 8. Stack edge (Traefik)

**Produção (Swarm):** o Traefik corre como serviço na stack **`infra-edge`**, com `placement` no **manager**, `read_only: true` e socket Docker read-only. A configuração estática inclui **três** providers: **`docker`** (contentores Compose, ex. Jenkins), **`swarm`** (serviços das stacks Swarm) e **`file`** (middlewares/serviços estáticos em `traefik/dynamic/`).

```bash
cd ~/infra/stacks/edge
docker compose -f docker-stack.yml --env-file ../../.env config \
  | sed '/^name:/d' \
  | sed -E 's/^([[:space:]]*published: )"([0-9]+)"/\1\2/' \
  > /tmp/infra-edge.stack.yml
docker stack deploy -c /tmp/infra-edge.stack.yml infra-edge
```

Se alterares **só** ficheiros montados em volume (`traefik/static/`, `traefik/dynamic/`) sem mudar o YAML da stack, o Swarm pode **não** recriar a tarefa. Nesse caso: `docker service update --force infra-edge_traefik`.

**Legado (Compose só):** `docker compose --env-file ../../.env up -d` com `docker-compose.yml` — útil em ambientes sem Swarm; em produção com Swarm, prefira o ficheiro **`docker-stack.yml`**.

- Certificados Let's Encrypt; e-mail ACME via variável oficial do Traefik no Compose (`TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL`), não via `${ACME_EMAIL}` dentro do YAML estático.
- Resolver ACME: **`httpChallenge`** no entrypoint `web`. O redirect global `web → websecure` não impede o challenge (o Traefik responde a `/.well-known/acme-challenge/` na porta 80 antes de aplicar o redirect).
- Se os logs mostrarem *client version 1.24 is too old*: `pull` + redeploy com imagem Traefik **v3.6+**.

### Dashboard Traefik (`https://traefik.lucaskaiut.com.br`)

- Middleware Basic Auth: `stacks/edge/traefik/dynamic/dashboard-auth.yml` (nome `traefik-dashboard-auth`).
- Segredos: `stacks/edge/secrets/dashboard.htpasswd` (**não** versionado). Bootstrap: copiar `dashboard.htpasswd.example`, depois `htpasswd -cB dashboard.htpasswd admin` e reiniciar Traefik.
- Validação: sem credenciais → **401** em `/dashboard/`; com `-u admin:...` → **200**.

### Middlewares dinâmicos (`traefik/dynamic/`)

| Ficheiro | Middleware(s) | Uso |
|----------|---------------|-----|
| `security-headers.yml` | `security-headers` | HSTS + headers aplicados globalmente no entrypoint `websecure` |
| `dashboard-auth.yml` | `traefik-dashboard-auth` | Basic Auth do dashboard |
| `cors-allow-all.yml` | `cors-allow-all` | CORS permissivo para APIs |
| `horus-api-docs-proxy.yml` | router/`horus-api-docs-proxy` | Proxy `/docs` do horus (legado) |
| `tasksautomation-apidog-docs.yml` | router/`tasksautomation-apidog-docs` | Proxy `/docs` do tasksautomation (legado) |

### Problemas comuns (Traefik / Compose)

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `required variable DOMAIN is missing` | `docker compose` sem `--env-file` / sem `.env` na pasta | Usar `--env-file` ou symlink conforme secção 7 |
| API Docker 1.24 too old (Traefik) | Imagem Traefik antiga vs Docker 29+ | Atualizar para Traefik v3.6+ |
| Erro ACME / e-mail inválido | `ACME_EMAIL` vazio ou `.env` com CRLF/BOM | Corrigir `.env`; confirmar vars no container Traefik |
| Dashboard `traefik.*` inacessível após **Swarm**; logs `port is missing` no provider **swarm** | No Swarm o Traefik exige label explícita `traefik.http.services.<nome>.loadbalancer.server.port` em cada serviço com `traefik.enable` | Definir essa label no serviço (ex.: `traefik.http.services.traefik.loadbalancer.server.port=80` no próprio Traefik) |
| Router devolve **404** e log `middleware "<x>@file" does not exist` | Label aponta para middleware `@file` que não existe em `traefik/dynamic/` | Criar o ficheiro do middleware em `traefik/dynamic/` (ou remover a label) e `docker service update --force infra-edge_traefik` |
| Navegador mostra **“Não seguro”** com HTTPS | Mistura HTTP/HTTPS, HSTS em falta, ou cadeia LE pouco compatível com clientes antigos | O Traefik aplica middleware **security-headers** (HSTS) em `websecure`; ACME usa `preferredChain: ISRG Root X1`. **Jenkins:** `JENKINS_URL` no `.env` tem de ser `https://jenkins.<DOMAIN>` (sem `http://`). |

---

## 9. Stack shared (MySQL + Redis)

**Produção (Swarm):**

```bash
cd ~/infra/stacks/shared
cp .env.example .env
docker compose -f docker-stack.yml --env-file .env config \
  | sed '/^name:/d' \
  | sed -E 's/^([[:space:]]*published: )"([0-9]+)"/\1\2/' \
  > /tmp/infra-shared.stack.yml
docker stack deploy -c /tmp/infra-shared.stack.yml infra-shared
```

**Legado:** `docker compose --env-file .env up -d` com `docker-compose.yml`.

- Imagens em produção: **`mysql:8.4`**, **`redis:7-alpine`**.
- Variáveis típicas: `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`.
- A imagem oficial inicializa **uma** base; mais bases: SQL manual ou `docker-entrypoint-initdb.d` (ver `stacks/shared/mysql/README.md` se existir).
- Apps alinham `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` com o shared quando usam essa base.

---

## 10. Aplicações em produção

### 10.1 Inventário (stacks Swarm ativas)

| Stack | Serviços | Imagem(ns) | Hostname | Deploy |
|-------|----------|------------|----------|--------|
| `infra-app-alura` | `app` (2), `scheduler`, `worker` (0) | `local/alura-api:latest` | `alura-api.lucaskaiut.com.br` | `./ci/deploy-app.sh alura` (build) |
| `infra-app-chat-one` | `app`, `redis`, `reverb`, `scheduler`, `worker` | `local/chat-one-api:latest`, `redis:7-alpine` | `chatone-api.noxtecnologias.com.br` | `./ci/deploy-app.sh chat-one` (build) |
| `infra-app-evolutionapi` | `evolutionapi`, `evolutionapi_postgres`, `evolutionapi_redis` | `evoapicloud/evolution-api:v2.3.7`, `postgres:15`, `redis:7.4-alpine` | `evolution.lucaskaiut.com.br` | `./ci/deploy-app.sh evolutionapi` (pull-only) |
| `infra-app-financeiro-borcath` | `app` (2), `worker` (0) | `local/financeiro-borcath-api:latest` | `financeiro-api.dborcath.com.br` | `./ci/deploy-app.sh financeiro-borcath` (build) |
| `infra-app-hedgedoc` | `database`, `hedgedoc` | `quay.io/hedgedoc/hedgedoc:1.10.7`, `postgres:17.7-alpine` | `docs.lucaskaiut.com.br` | manual (`docker stack deploy`) |
| `infra-app-n8n` | `n8n` | `n8nio/n8n:2.15.1` | `n8n.lucaskaiut.com.br` | `./ci/deploy-app.sh n8n` (pull-only) |
| `infra-app-nox-cms` | `app` (2), `scheduler`, `worker` | `local/nox-cms-api:latest` | `cms-api.noxtecnologias.com.br` | `./ci/deploy-app.sh nox-cms` (build) |
| `infra-app-nox-schduler` | `app` (2), `horizon`, `scheduler` | `local/nox-schduler-app:latest` | `api.noxagenda.com.br` | `./ci/deploy-app.sh nox-schduler` (build) |
| `infra-app-uptime-kuma` | `uptime-kuma` | `louislam/uptime-kuma:2.2.1` | `uptime.lucaskaiut.com.br` | manual (`docker stack deploy`) |
| `infra-app-vulcano` | `app` (2), `scheduler`, `worker` (0) | `local/vulcano-api:latest` | `sistema-api.dborcath.com.br` | `./ci/deploy-app.sh vulcano` (build) |
| `infra-netdata` | `netdata` | `netdata/netdata:stable` | `netdata.lucaskaiut.com.br` | manual (`docker stack deploy`) |
| `infra-opensearch` | `opensearch` | `opensearchproject/opensearch:2.18.0` | `opensearch.lucaskaiut.com.br` | manual (`docker stack deploy`) |

Notas:

- `worker` a **0 réplicas** em `alura`, `financeiro-borcath` e `vulcano` — o serviço existe na stack mas está escalado a zero em produção.
- `hedgedoc` a **0 réplicas** (só o `database` Postgres está a correr) — a aplicação em `docs.lucaskaiut.com.br` está atualmente inacessível.
- Apps com `build` constroem imagem local `local/<slug>-api:latest` a partir do clone do monorepo dentro da pasta da stack (gitignored); após o build o `deploy-app.sh` força a recriação das tarefas (`APP_SWARM_FORCE_SERVICE_UPDATE=1`) porque a tag `:latest` não muda o spec da stack.
- Apps com `pull-only` (`evolutionapi`, `n8n`) apenas fazem `docker compose pull` + `stack deploy` (imagem pública, sem build).
- `hedgedoc`, `netdata`, `opensearch`, `uptime-kuma` **não têm** `ci/apps/<slug>.sh` — deploy manual via `docker stack deploy` (ver README de cada pasta quando existir).

### 10.2 Métodos de deploy

- **Build local + Swarm:** `./ci/deploy-app.sh <slug>` — clona/atualiza o monorepo, faz `docker compose build`, renderiza `docker-stack.yml` e faz `docker stack deploy`. Exemplos: `alura`, `chat-one`, `financeiro-borcath`, `nox-cms`, `nox-schduler`, `vulcano`.
- **Pull-only:** `./ci/deploy-app.sh <slug>` com `APP_COMPOSE_PULL_ONLY=1`. Exemplos: `evolutionapi`, `n8n`.
- **Manual:** `docker stack deploy` direto (sem `ci/apps/<slug>.sh`). Exemplos: `hedgedoc`, `netdata`, `opensearch`, `uptime-kuma`.

### 10.3 Apps definidas no repo mas **sem** stack ativa em produção

Estas pastas/scripts/jobs existem no repositório mas **não** correspondem a uma stack a correr na VPS:

| Slug | `ci/apps/` | Jenkins job | Observação |
|------|-----------|-------------|------------|
| `ematricula` | sim | `deploy-ematricula-webhook` | Documentada na secção 12 |
| `horus` | sim | `deploy-horus-webhook` | Configuração `horus-api-docs-proxy` ainda em `traefik/dynamic/` |
| `plutao` | sim | `deploy-plutao-webhook` | — |
| `toth` | sim | `deploy-toth-webhook` | — |
| `toth-ai` | sim | — | pull-only (ollama/litellm) |
| `tasksautomation` | sim | `deploy-tasksautomation-webhook` | Configuração `tasksautomation-apidog-docs` ainda em `traefik/dynamic/` |
| `atena` | sim | `deploy-atena-webhook` | — |
| `demo` | não | — | stack de demonstração |

Ao retomar qualquer uma destas apps, validar DNS, `.env` e rede `infra_shared` conforme a secção 10 do template.

### 10.4 Nova aplicação (template)

1. `cp -r stacks/apps/_template stacks/apps/<slug>`
2. Substituir `myservice` pelo slug; ajustar imagem, portas e labels Traefik (`<slug>.${DOMAIN}`).
3. DNS para o hostname.
4. Se precisar de MySQL/Redis: rede **`infra_shared`**, `DB_HOST=mysql`, `REDIS_HOST=redis`, prefixos Redis por app.
5. Deploy automatizado: ficheiro `ci/apps/<slug>.sh` (ver secção 13); se for manual, documentar no README da pasta.

---

## 11. Notas por aplicação (referência)

### n8n

- Pasta **`stacks/apps/n8n/`**, hostname **`n8n.${DOMAIN}`** (`n8n.lucaskaiut.com.br`), TLS no Traefik. Imagem **`n8nio/n8n`** com **tag fixa** (em produção **2.15.1**).
- Persistência: SQLite em volume Docker **`n8n_data`**. **Uma réplica** no Swarm; não aumentar réplicas sem migrar para PostgreSQL.
- **Deploy:** `cd ~/infra && ./ci/deploy-app.sh n8n` (pull-only; com Swarm ativo faz `docker stack deploy` na stack **`infra-app-n8n`**).
- **Notificações Jenkins → n8n:** fluxo em `ci/n8n/workflows/jenkins-deploy-notify.json`; publicar com `./ci/n8n/deploy-jenkins-deploy-notify-workflow.sh` (usa `N8N_API_URL` / `N8N_API_KEY` no `.env` raiz). Webhook de produção: `https://n8n.lucaskaiut.com.br/webhook/jenkins-deploy-notify` (variável `N8N_DEPLOY_WEBHOOK_URL` no `.env` do Jenkins).

### evolutionapi

- Pasta **`stacks/apps/evolutionapi/`**, hostname **`evolution.lucaskaiut.com.br`**. Imagem **`evoapicloud/evolution-api:v2.3.7`** com **Postgres e Redis dedicados** dentro da própria stack (não usa o shared).
- **Deploy:** `./ci/deploy-app.sh evolutionapi` (pull-only). Rede interna **`infra_evolutionapi_internal`**.

### HedgeDoc

- Pasta **`stacks/apps/hedgedoc/`**, hostname **`docs.lucaskaiut.com.br`**, Postgres dedicado. Acesso anónimo e registo por email **desativados**.
- Deploy **manual** (sem `ci/apps/`): ver `stacks/apps/hedgedoc/README.md`.

### Uptime Kuma

- Pasta **`stacks/apps/uptime-kuma/`**, hostname **`uptime.lucaskaiut.com.br`**, imagem **`louislam/uptime-kuma:2.2.1`**. Deploy **manual**.

### Netdata

- Pasta **`stacks/apps/netdata/`**, hostname **`netdata.lucaskaiut.com.br`** (fixo no YAML). Socket Docker em read-only, hostname do agente `vps-contabo`. Deploy **manual** via `docker stack deploy`.

### OpenSearch

- Pasta **`stacks/apps/opensearch/`**, hostname **`opensearch.lucaskaiut.com.br`**, imagem **`opensearchproject/opensearch:2.18.0`**, `discovery.type=single-node`, plugin de segurança **desativado**. Deploy **manual**.

---

## 12. Jenkins (`stacks/jenkins/`)

### Imagem

- Imagem local **`infra-jenkins:lts`** (construída a partir de `image/`).
- Plugins: `configuration-as-code`, `git`, `workflow-aggregator`, `credentials-binding`, `ssh-credentials`, `generic-webhook-trigger`.
- **Docker CLI** + **docker compose** v2 na imagem para jobs que falam com o daemon do host.
- CasC em `image/casc/jenkins.yaml`; init Groovy em `image/init.groovy.d/` (credencial GitHub opcional, job **ci-smoke** na **primeira** criação do volume).

### Compose (fora do Swarm)

O Jenkins **não** é deployado com `docker stack deploy`: o Swarm **não** suporta `group_add`, necessário para o utilizador do Jenkins aceder ao socket Docker do host.

- Volume `jenkins_home`.
- Mount **`${INFRA_HOST_PATH}:/infra-deploy:rw`** — mesmo clone **infra** que na VPS.
- **`/var/run/docker.sock`** + **`group_add: ${DOCKER_GID}`** — GID do grupo `docker` no host (`getent group docker | cut -d: -f3`).
- Rede **`infra_edge`** como **external** (overlay **attachable** criada pelo bootstrap) para o Traefik descobrir o serviço via provider **Docker** clássico.

### Variáveis (`stacks/jenkins/.env`)

| Variável | Uso |
|----------|-----|
| `DOMAIN` | Host `jenkins.${DOMAIN}` |
| `JENKINS_URL` | URL pública HTTPS (em produção `https://jenkins.lucaskaiut.com.br`) |
| `JENKINS_ADMIN_PASSWORD` | Utilizador `admin` (CasC) |
| `GITHUB_*` | PAT opcional → credencial `github-readonly` no primeiro boot |
| `INFRA_HOST_PATH` | Caminho absoluto no host para o repo infra |
| `DOCKER_GID` | GID do grupo docker no host |
| `N8N_DEPLOY_WEBHOOK_URL` | URL `POST` do webhook n8n (em produção `https://n8n.lucaskaiut.com.br/webhook/jenkins-deploy-notify`). Se vazio, o script `ci/notify-n8n-deploy.sh` tenta `N8N_API_URL` do `.env` montado em `/infra-deploy`. |

Após alterar a **imagem** Jenkins, na VPS: `docker compose build && docker compose up -d` em `stacks/jenkins/`.

```bash
cd ~/infra/stacks/jenkins
cp .env.example .env
docker compose build && docker compose up -d
```

### Jobs

Jobs presentes no Jenkins de produção (13):

| Job | Função |
|-----|--------|
| **ci-smoke** | Checkout do repo infra + echo (smoke CI) |
| **deploy-alura-webhook** | Webhook push em `main` no repo **alura** → `./ci/deploy-app.sh alura` |
| **deploy-atena-webhook** | Webhook push em `main` no repo **atena** → `./ci/deploy-app.sh atena` |
| **deploy-chat-one-webhook** | Webhook push em `main` no repo **chat-one** → `./ci/deploy-app.sh chat-one` |
| **deploy-ematricula-webhook** | Webhook push em `main` no repo **ematricula** (alterações em `api/`) → `./ci/deploy-app.sh ematricula` |
| **deploy-financeiro-borcath-webhook** | Webhook push em `main` no repo **financeiro-borcath** → `./ci/deploy-app.sh financeiro-borcath` |
| **deploy-horus-webhook** | Webhook push em `main` no repo **horus** (alterações em `api/`) → `./ci/deploy-app.sh horus` |
| **deploy-nox-cms-webhook** | Webhook push em `main` no repo **nox-cms** → `./ci/deploy-app.sh nox-cms` |
| **deploy-nox-schduler-webhook** | Webhook push no repo **nox-schduler** → `./ci/deploy-app.sh nox-schduler` |
| **deploy-plutao-webhook** | Webhook push em `main` no repo **plutao** → `./ci/deploy-app.sh plutao` |
| **deploy-tasksautomation-webhook** | Webhook no repo **tasksautomation** → `./ci/deploy-app.sh tasksautomation` |
| **deploy-toth-webhook** | Webhook push em `main` no repo **toth** → `./ci/deploy-app.sh toth` |
| **deploy-vulcano-webhook** | Webhook push em `main` no repo **vulcano** → `./ci/deploy-app.sh vulcano` |

Jenkinsfiles correspondentes em `ci/jenkins/Deploy<App>Webhook.Jenkinsfile`; seeds em `ci/jenkins/seed-deploy-*.groovy`. Modelo genérico: `ci/jenkins/DeployApp.Jenkinsfile` / `DeployApp.Jenkinsfile.example`.

**API Jenkins / CLI:** com `JENKINS_URL` em HTTPS (Traefik), usar essa URL para `jenkins-cli` e REST. Chamadas a `http://127.0.0.1:8080` a partir do contentor podem receber **403** (*Unexpected request origin*); na VPS preferir `https://jenkins.lucaskaiut.com.br/...`.

**Generic Webhook Trigger e `copy-job`:** ao duplicar um job (`jenkins copy-job`), o Jenkins **copia o XML** do trigger, incluindo **`tokenCredentialId`**. Se só se alterar o `scriptPath` para outro Jenkinsfile, o job pode continuar a usar o token da app de origem; o webhook devolve `Did not find any jobs with GenericTrigger configured! A token was supplied.` Corrigir com `get-job | sed` em `tokenCredentialId` (e opcionalmente `causeString`) + `update-job`, ou `./ci/jenkins/create-webhook-job-from-template.sh` com o ID da credencial correta.

**Manutenção:** alterações em `init.groovy.d` **não** atualizam jobs já criados — editar o job no Jenkins ou recriar o volume (perde estado).

**ci-smoke:** não usar `options { timestamps() }` sem o plugin Timestamper.

### Webhooks (padrão por app)

Para cada app com deploy automático:

1. **Gerar um segredo** (guardar só em gestor de passwords ou na credencial Jenkins — não versionar): `openssl rand -hex 32`.
2. Credencial Jenkins **Secret text**: ID **`<slug>-webhook-token`** (ex.: `vulcano-webhook-token`), valor = segredo.
3. **Job no Jenkins:** Jenkinsfile `ci/jenkins/Deploy<Vulcano>Webhook.Jenkinsfile` no repo **infra**. Criar/corrigir com `./ci/jenkins/create-webhook-job-from-template.sh` (atualiza `tokenCredentialId` e `causeString` no XML persistido; não basta mudar só o `scriptPath` no UI).
4. **GitHub** (repo da app): *Settings* → *Webhooks* → **Payload URL** `https://jenkins.<DOMAIN>/generic-webhook-trigger/invoke?token=<MESMO_SEGREDO>`, **Content type** `application/json`, evento **push** na branch `main`.
5. Build manual do job corre deploy **sempre** (ignora filtros de `api/`/branch).

**`git pull` no mount `/infra-deploy`:** repos públicos HTTPS costumam funcionar; repos privados podem exigir PAT no host ou ajuste de credenciais no Jenkins. UID **jenkins** (geralmente 1000) deve conseguir escrever no `.git` montado. Os jobs webhook fazem `git fetch origin main` + `git reset --hard origin/main` no clone `/infra-deploy`.

**Credencial via API:** `scripts/jenkins-create-cred.py` mostra como criar uma credencial Secret text via `scriptText` (adaptar para o job/credencial pretendidos).

---

## 13. CI — `ci/deploy-app.sh` e novas apps

- **`ci/apps/<slug>.sh`:** define `APP_COMPOSE_DIR` e opcionalmente `APP_GIT_SUBDIR`, `APP_GIT_REMOTE`, `APP_GIT_BRANCH`, `APP_GIT_USE_SSH`.
- **Swarm:** por omissão `APP_USE_SWARM=1`. Com **Swarm ativo** (manager), o script usa **`docker stack deploy`** na stack `APP_SWARM_STACK_NAME`. Se `APP_USE_SWARM=1` mas o daemon **não** estiver em Swarm, o `deploy-app.sh` **não falha**: emite aviso, usa **`docker compose up`** e define por omissão `APP_COMPOSE_SCALES=app=2`.
- **Pull-only:** `APP_COMPOSE_PULL_ONLY=1` faz só `docker compose pull` (sem build) — usado por `evolutionapi`, `n8n`, `toth-ai`.
- **Imagem local `local/...:latest` no Swarm:** após `docker compose build`, a tag pode apontar para uma digest nova sem o **`stack deploy`** recriar tarefas. Para evitar um segundo ciclo manual de `docker service update --force`, os scripts usam **`APP_SWARM_FORCE_SERVICE_UPDATE=1`** com `APP_SWARM_FORCE_IMAGE` / `APP_SWARM_FORCE_SERVICE_ROLES` (ou `APP_SWARM_FORCE_IMAGES` para múltiplas imagens).
- **Health probe durante deploy:** `APP_HTTP_PROBE_SERVICE_HOST` (+ `APP_HTTP_PROBE_PATH`, default `/up`) liga o `ci/http-probe-loop.sh` para amostrar o HTTPS público enquanto o deploy decorre.
- **Guarda por subpath:** `APP_DEPLOY_SUBPATH_GUARD=api` (ou `backend`) faz o deploy abortar se o intervalo Git (`DEPLOY_SUBPATH_GIT_RANGE`) não tocar naquela subpasta.
- **Compose forçado:** `export APP_USE_SWARM=0` antes do script — `docker compose up -d` e `APP_COMPOSE_SCALES` em `ci/apps/<slug>.sh`.
- **`ci/swarm-bootstrap.sh`:** inicialização do Swarm e criação das redes overlay (ver secção 3.1).
- Modelo vazio: `ci/apps/_template.sh.example`.

---

## 14. Versionamento em Git

**Versionar:** `stacks/`, `ci/`, `docs/`, `scripts/`, `README.md`, `.env.example`, exemplos de segredos (`*.example`).

**Não versionar:** `.env` com segredos, `stacks/shared/.env`, `stacks/jenkins/.env`, `stacks/apps/*/.env`, `stacks/edge/secrets/dashboard.htpasswd`, `acme.json` em bind mount, chaves SSH e tokens de webhook em `stacks/jenkins/keys-*/`, credenciais de registry, clones de aplicações em pastas gitignored (ex.: `alura/` dentro da stack).

**Produção:** `.env` no servidor com permissões restritas (`chmod 600`); evoluir para Vault/sops quando fizer sentido.

---

## 15. Checklist rápido de diagnóstico

1. **Redes:** `docker network ls | grep infra_` (driver **overlay** em produção Swarm)
2. **Swarm:** `docker info | grep -i swarm`
3. **Stacks:** `docker stack ls`; serviços por stack `docker service ls`
4. **Ordem:** bootstrap → shared → edge → apps → jenkins (Compose)
5. **Compose / stack:** `--env-file` correto; deploy Swarm via `docker compose -f docker-stack.yml … config` antes de `docker stack deploy`
6. **Traefik:** labels em **`deploy.labels`** nas stacks Swarm; em Compose clássico, labels ao nível do serviço
7. **App com BD:** app na rede `infra_shared`, variáveis DB/Redis corretas
8. **Jenkins deploy:** `INFRA_HOST_PATH`, `DOCKER_GID`, mount e socket ativos; `docker exec infra_jenkins docker ps` funciona
9. **Webhooks:** credenciais com ID exatos (`<slug>-webhook-token`), URL GitHub `https://jenkins.<DOMAIN>/generic-webhook-trigger/invoke?token=<segredo>` igual ao valor da credencial; branch `main`; pipelines com `APP_DEPLOY_SUBPATH_GUARD` só fazem deploy se houver mudanças na subpasta (exceto build manual)
10. **Stacks Swarm:** `docker stack ps <nome>` para ver tarefas a falhar
11. **404 em path Laravel (`/api/...`):** se `X-Powered-By: PHP`, o pedido chegou à app — confirmar `php artisan route:list` no contentor e alinhar código deployado (push + `./ci/deploy-app.sh`) com o repositório da app; não atribuir a Traefik/Nginx sem este passo.
12. **404 em router inteiro:** verificar log do Traefik por `middleware "<x>@file" does not exist` (ver secção 8).

---

## 16. Migração Compose (bridge) → Swarm (overlay)

Resumo para uma VPS que já corria **edge** / **shared** / **apps** só com Compose:

1. **Janela de manutenção** breve ou aceitar paragem enquanto se trocam as redes.
2. Parar stacks na ordem inversa habitual: apps → **edge** (Traefik) → **shared** (último se quiseres minimizar tempo sem BD).
3. Remover redes **`infra_edge`** e **`infra_shared`** se ainda existirem como **bridge** (`docker network rm …` só sem contentores ligados).
4. Correr **`ci/swarm-bootstrap.sh`** com **`SWARM_ADVERTISE_ADDR`** definido.
5. Subir **shared**, **edge** e **apps** com os comandos das secções 8, 9 e 10 (ficheiros **`docker-stack.yml`**).
6. Subir **Jenkins** com **`docker compose up -d`** (rede `infra_edge` externa).
7. Confirmar volumes Docker (`docker volume ls`): os nomes devem alinhar com o projeto/stack (`infra-shared_…`, `infra-edge_…`). Se necessário, ajustar antes com cópia de dados (fora do âmbito deste doc).

---

## 17. Evoluções possíveis (não implementadas)

- Allowlist IP / VPN no dashboard Traefik e nos routers de monitorização (Netdata, OpenSearch)
- Secrets centralizados (Vault, sops) em vez de `.env` nos hosts
- Vários nós Swarm (workers) e placement por constraints

Este documento substitui os antigos ficheiros por etapa (`01`–`07`), `convencoes-e-decisoes.md` e `versionamento-git.md`.
