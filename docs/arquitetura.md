# Arquitetura e operação da infraestrutura

Documento único: visão da plataforma Docker na VPS, decisões técnicas, como subir e corrigir problemas. Público-alvo: equipa que mantém **infra** (repositório separado do código das aplicações).

---

## 1. Papel deste repositório

| Repositório | Conteúdo |
|-------------|----------|
| **infra** (este) | Traefik, redes overlay Swarm, MySQL/Redis partilhados, `docker-stack.yml` + Compose (build / Jenkins), scripts `ci/`, documentação operacional |
| **Aplicações** (ex.: `ematricula`) | Código, testes, lógica de negócio. A imagem da API eMatricula constrói-se a partir de `ematricula/api` no monorepo; alterações de produto fazem-se **lá**, não na infra |

---

## 2. Mapa de pastas

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Traefik (TLS, roteamento): `docker-compose.yml` (legado) ou **`docker-stack.yml`** (Swarm) |
| `stacks/shared/` | MySQL + Redis: **`docker-stack.yml`** (Swarm) ou Compose legado |
| `stacks/apps/<slug>/` | `docker-compose.yml` (build local da imagem) + **`docker-stack.yml`** quando o deploy em produção é Swarm |
| `stacks/apps/_template/` | Modelo para copiar ao criar nova app simples |
| `stacks/jenkins/` | Jenkins (CI/CD), imagem customizada, CasC, init Groovy |
| `ci/` | `deploy-app.sh`, `ci/apps/<slug>.sh`, Jenkinsfiles em `ci/jenkins/` |

---

## 3. Redes e nomenclatura

- **`infra_edge`** — Rede **overlay** (`docker network create -d overlay --attachable infra_edge`), partilhada por Traefik (stack Swarm), apps expostas ao Traefik e pelo **Jenkins** (Compose clássico, que se liga à mesma rede).
- **`infra_shared`** — Rede **overlay** (`… infra_shared`) para MySQL, Redis e apps que precisam de BD/cache. Serviços noutras stacks Swarm na mesma rede resolvem **`mysql`** e **`redis`** pelo nome do serviço na stack `infra-shared`.
- **Swarm:** um nó manager na VPS (`docker swarm init`); stacks nomeadas `infra-edge`, `infra-shared`, `infra-app-ematricula`, etc.
- **Compose clássico:** mantido para **build** da imagem (`docker compose -f docker-compose.yml build`) e para **Jenkins** (limitação: `group_add` para o socket Docker **não** é suportado em `docker stack deploy`).
- **API eMatricula (Swarm):** serviço `app` com **2 réplicas**, `deploy.update_config.order: start-first` e `parallelism: 1` — atualização rolling (nova tarefa sobe e passa a saudável antes de retirar a antiga).

**Regra:** um par MySQL + Redis para todas as apps; isolamento em Redis com **prefixos** (ex. Laravel `REDIS_PREFIX`).

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
| Proxy / TLS | Traefik **v3.6+** | Labels Docker, ACME; evita *client API 1.24 too old* com Docker Engine 29+ |
| Orquestração | **Docker Swarm** (stacks `infra-edge`, `infra-shared`, apps) + Compose para build e Jenkins | Rolling update (`start-first`) na API; uma VPS manager |
| ACME | `tlsChallenge` | Menos conflito com redirecionamentos HTTP→HTTPS do que HTTP-01 na porta 80 em alguns cenários |
| Deploy por app | `ci/deploy-app.sh <slug>` + `ci/apps/<slug>.sh` | Configuração mínima por app; Jenkins na mesma VPS monta o clone **infra** e o **socket Docker** (sem SSH no pipeline de deploy) |
| Jenkins | Imagem `lts-jdk21`, CasC, init Groovy | Java 21 exigido pelo Jenkins LTS atual; job `ci-smoke` na primeira subida do volume |

**Traefik (segurança):** `exposedByDefault: false`; só entra no proxy quem tiver `traefik.enable=true`. Socket Docker no Traefik em **read-only** onde aplicável. Jenkins usa o socket **read-write** para `docker compose` — implica risco elevado se o Jenkins for comprometido; usar só em VPS dedicada, HTTPS forte e password admin forte.

---

## 5. Ordem de arranque na VPS

1. **`ci/swarm-bootstrap.sh`** — Swarm + redes overlay `infra_edge` e `infra_shared` (uma vez, ou após migração).
2. **shared (Swarm)** — `docker stack deploy` com `stacks/shared/docker-stack.yml` → stack **`infra-shared`** (MySQL e Redis).
3. **edge (Swarm)** — `docker stack deploy` com `stacks/edge/docker-stack.yml` → **`infra-edge`** (Traefik).
4. **apps (Swarm)** — ex.: eMatricula via `./ci/deploy-app.sh ematricula` (build Compose + deploy stack **`infra-app-ematricula`**).
5. **jenkins (Compose)** — `docker compose up -d` em `stacks/jenkins/` (liga à rede **`infra_edge`** já existente).

Sem **shared** a correr, apps que dependem de MySQL/Redis falham ou ficam à espera.

---

## 6. DNS e firewall

- Registos **`A`** (ou wildcard) para: `traefik.<DOMAIN>`, `demo.<DOMAIN>`, `ematricula-api.<DOMAIN>`, `jenkins.<DOMAIN>`, etc., conforme as stacks ativas.
- **UFW (exemplo):** `OpenSSH`, `80/tcp`, `443/tcp` permitidos.

---

## 7. Ficheiros `.env` e interpolação do Compose

- Na **raiz** do clone (`~/infra`): `DOMAIN`, `ACME_EMAIL`, etc., para stacks que usam `--env-file ../../.env` (ex.: **edge**, **demo**).
- **`${DOMAIN}` nos labels Traefik** do YAML é resolvido pelo **Compose** a partir do ficheiro passado com `--env-file` (ou `.env` na pasta do projeto), **não** pelo `env_file:` interno do serviço (esse injeta variáveis **dentro** do container).

**Boas práticas:**

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
docker compose --env-file ../../.env ps
```

**Atalho:** `ln -sf ../../.env .env` na pasta da stack para não repetir `--env-file`.

**Stacks com `.env` local:** `stacks/shared/.env`, `stacks/apps/ematricula/.env`, `stacks/jenkins/.env` — não versionados; usar `.env.example` como modelo.

---

## 8. Stack edge (Traefik)

**Produção (Swarm):** o Traefik corre como serviço na stack **`infra-edge`**, com `placement` no **manager** e socket Docker read-only. A configuração estática inclui **dois** providers: **`docker`** (contentores Compose, ex. Jenkins) e **`swarm`** (serviços das stacks Swarm).

```bash
cd ~/infra/stacks/edge
docker compose -f docker-stack.yml --env-file ../../.env config \
  | sed '/^name:/d' \
  | sed -E 's/^([[:space:]]*published: )"([0-9]+)"/\1\2/' \
  > /tmp/infra-edge.stack.yml
docker stack deploy -c /tmp/infra-edge.stack.yml infra-edge
```

**Legado (Compose só):** `docker compose --env-file ../../.env up -d` com `docker-compose.yml` — útil em ambientes sem Swarm; em produção com Swarm, prefira o ficheiro **`docker-stack.yml`**.

- Certificados Let's Encrypt; e-mail ACME via variável oficial do Traefik no Compose (fiável vs expandir `${ACME_EMAIL}` dentro de YAML estático montado).
- Se os logs mostrarem *client version 1.24 is too old*: `pull` + redeploy com imagem Traefik **v3.6+**.

### Dashboard Traefik (`https://traefik.<DOMAIN>`)

- Middleware Basic Auth: `stacks/edge/traefik/dynamic/dashboard-auth.yml`.
- Segredos: `stacks/edge/secrets/dashboard.htpasswd` (**não** versionado). Bootstrap: copiar `dashboard.htpasswd.example`, depois `htpasswd -cB dashboard.htpasswd admin` e reiniciar Traefik.
- Validação: sem credenciais → **401** em `/dashboard/`; com `-u admin:...` → **200**.

### Problemas comuns (Traefik / Compose)

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `required variable DOMAIN is missing` | `docker compose` sem `--env-file` / sem `.env` na pasta | Usar `--env-file` ou symlink conforme secção 7 |
| API Docker 1.24 too old (Traefik) | Imagem Traefik antiga vs Docker 29+ | Atualizar para Traefik v3.6+ |
| Erro ACME / e-mail inválido | `ACME_EMAIL` vazio ou `.env` com CRLF/BOM | Corrigir `.env`; confirmar vars no container Traefik |
| Dashboard `traefik.*` inacessível após **Swarm**; logs `port is missing` no provider **swarm** | No Swarm o Traefik exige label explícita `traefik.http.services.<nome>.loadbalancer.server.port` em cada serviço com `traefik.enable` (incluindo o próprio Traefik) | Em `stacks/edge/docker-stack.yml` está definido `traefik.http.services.traefik.loadbalancer.server.port=80` junto do router `api@internal` |

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

- Variáveis típicas: `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`.
- A imagem oficial inicializa **uma** base; mais bases: SQL manual ou `docker-entrypoint-initdb.d` (ver `stacks/shared/mysql/README.md` se existir).
- Apps alinham `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` com o shared quando usam essa base.

---

## 10. Nova aplicação (template)

1. `cp -r stacks/apps/_template stacks/apps/<slug>`
2. Substituir `myservice` pelo slug; ajustar imagem, portas e labels Traefik (`<slug>.${DOMAIN}`).
3. DNS para o hostname.
4. `docker compose --env-file ../../../.env up -d` na pasta da app (se usar só edge).
5. Se precisar de MySQL/Redis: rede **`infra_shared`**, `DB_HOST=mysql`, `REDIS_HOST=redis`, prefixos Redis por app.
6. Deploy automatizado: ficheiro `ci/apps/<slug>.sh` (ver secção 13).

---

## 11. Stack eMatricula (API Laravel)

**Serviços nesta stack:** `app` (Nginx + PHP-FPM, exposto pelo Traefik), `horizon`, `scheduler`. Código-fonte: clone do monorepo em `stacks/apps/ematricula/ematricula/`; o **Dockerfile** usa `ematricula/api`.

**Hostname Traefik:** `ematricula-api.${DOMAIN}` — o `.env` da stack deve incluir **`DOMAIN`** alinhado à raiz; Laravel precisa de `APP_URL` e `SANCTUM_*` coerentes com esse hostname (`stacks/apps/ematricula/.env.example`).

**Primeira subida (após `ci/swarm-bootstrap.sh`, stacks `infra-shared` e `infra-edge`):**

```bash
cd ~/infra/stacks/apps/ematricula
git clone https://github.com/lucaskaiut/ematricula.git ematricula
cp .env.example .env
cd ~/infra && ./ci/deploy-app.sh ematricula
```

Para testar só com Compose local (sem Swarm), comentar `APP_USE_SWARM` em `ci/apps/ematricula.sh` ou usar `docker compose build && docker compose up -d` na pasta da stack.

- `DB_HOST=mysql`, `REDIS_HOST=redis`, credenciais DB alinhadas ao **shared**.
- Primeiro arranque do `app` pode correr migrações (`migrate --force`).
- TLS termina no Traefik; a imagem envia `HTTPS` / `X-Forwarded-Proto` ao PHP conforme necessário.

**Atualizar / deploy:**

```bash
cd ~/infra && ./ci/deploy-app.sh ematricula
```

O script faz **`docker compose -f docker-compose.yml build`** (imagem `local/ematricula-app:latest`), renderiza **`docker-stack.yml`** com `docker compose … config` (interpolação de `${DOMAIN}` e restantes variáveis a partir do `.env` da stack) e corre **`docker stack deploy`** na stack **`infra-app-ematricula`**. O serviço `app` tem **2 réplicas**, healthcheck, labels Traefik em **`deploy.labels`** (exigência do provider Swarm) e **`deploy.update_config`** com **`order: start-first`**, **`parallelism: 1`** e **`failure_action: rollback`** para rolling update. `horizon` e `scheduler` ficam com **`restart_policy`** (o Swarm ignora `depends_on` entre serviços).

---

## 12. Jenkins (`stacks/jenkins/`)

### Imagem

- Base `jenkins/jenkins:lts-jdk21`.
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
| `JENKINS_URL` | URL pública HTTPS (alinhada ao Traefik) |
| `JENKINS_ADMIN_PASSWORD` | Utilizador `admin` (CasC) |
| `GITHUB_*` | PAT opcional → credencial `github-readonly` no primeiro boot |
| `INFRA_HOST_PATH` | Caminho absoluto no host para o repo infra |
| `DOCKER_GID` | GID do grupo docker no host |

```bash
cd ~/infra/stacks/jenkins
cp .env.example .env
docker compose build && docker compose up -d
```

### Jobs

| Job | Origem | Função |
|-----|--------|--------|
| **ci-smoke** | Init Groovy (só volume novo) | Checkout do repo infra + echo (smoke CI) |
| **deploy-app** | Criar via `ci/jenkins/seed-deploy-app-job.groovy` ou Pipeline from SCM → `ci/jenkins/DeployApp.Jenkinsfile` | Parâmetro `APP_SLUG`; `git pull` + `./ci/deploy-app.sh` em `/infra-deploy` |
| **deploy-ematricula-webhook** | Seed `ci/jenkins/seed-deploy-ematricula-webhook-job.groovy` ou SCM → `DeployEmatriculaWebhook.Jenkinsfile` | Webhook GitHub: push em `main` no repo **ematricula** com alterações em **`api/`** |

**Manutenção:** alterações em `init.groovy.d` **não** atualizam jobs já criados — editar o job no Jenkins ou recriar o volume (perde estado).

**ci-smoke:** não usar `options { timestamps() }` sem o plugin Timestamper.

### Webhook eMatricula (configuração única)

1. Credencial **Secret text**, ID **`ematricula-webhook-token`** (valor aleatório longo).
2. Job **deploy-ematricula-webhook** apontando ao Jenkinsfile indicado acima.
3. No GitHub (**repo ematricula**): Webhook POST `https://jenkins.<DOMAIN>/generic-webhook-trigger/invoke?token=<MESMO_SEGREDO>`, `application/json`, evento **push**.
4. Build manual no Jenkins ignora filtros de branch/`api/` e corre deploy sempre.

**`git pull` no mount `/infra-deploy`:** repos públicos HTTPS costumam funcionar; repos privados podem exigir PAT no host ou ajuste de credenciais no Jenkins. UID **jenkins** (geralmente 1000) deve conseguir escrever no `.git` montado.

---

## 13. CI — `ci/deploy-app.sh` e novas apps

- **`ci/apps/<slug>.sh`:** define `APP_COMPOSE_DIR`, e opcionalmente `APP_GIT_SUBDIR`, `APP_GIT_REMOTE`, `APP_GIT_BRANCH`.
- **Swarm (ex.: eMatricula):** por omissão `APP_USE_SWARM=1` em `ci/apps/ematricula.sh`. Com **Swarm ativo** (manager), o script usa **`docker stack deploy`**. Se `APP_USE_SWARM=1` mas o daemon **não** estiver em Swarm, o `deploy-app.sh` **não falha**: emite aviso, usa **`docker compose up`** e define por omissão `APP_COMPOSE_SCALES=app=2` quando ainda não estava definido.
- **Compose forçado:** `export APP_USE_SWARM=0` antes do script — `docker compose up -d` e `APP_COMPOSE_SCALES` em `ci/apps/<slug>.sh` quando aplicável.
- **`ci/swarm-bootstrap.sh`:** inicialização do Swarm e criação das redes overlay (ver secção 3.1).
- Modelo vazio: `ci/apps/_template.sh.example`.

---

## 14. Versionamento em Git

**Versionar:** `stacks/`, `ci/`, `docs/`, `README.md`, `.env.example`, `.gitignore`, exemplos de segredos (`*.example`).

**Não versionar:** `.env` com segredos, `stacks/shared/.env`, `stacks/jenkins/.env`, `stacks/apps/*/.env`, `stacks/edge/secrets/dashboard.htpasswd`, `acme.json` em bind mount, chaves SSH, tokens Jenkins, credenciais de registry, clones de aplicações em pastas gitignored (ex.: `ematricula/` dentro da stack).

**Produção:** `.env` no servidor com permissões restritas (`chmod 600`); evoluir para Vault/sops quando fizer sentido.

---

## 15. Checklist rápido de diagnóstico

1. **Redes:** `docker network ls | grep infra_` (driver **overlay** em produção Swarm)
2. **Swarm:** `docker info | grep -i swarm`
3. **Ordem:** bootstrap → shared → edge → apps → jenkins (Compose)
4. **Compose / stack:** `--env-file` correto; deploy Swarm via `docker compose -f docker-stack.yml … config` antes de `docker stack deploy`
5. **Traefik:** labels em **`deploy.labels`** nas stacks Swarm; em Compose clássico, labels ao nível do serviço
6. **App com BD:** app na rede `infra_shared`, variáveis DB/Redis corretas
7. **Jenkins deploy:** `INFRA_HOST_PATH`, `DOCKER_GID`, mount e socket ativos; `docker exec infra_jenkins docker ps` funciona
8. **Webhook:** credencial ID exata `ematricula-webhook-token`, URL com mesmo token, branch `main`, paths `api/`
9. **Stacks Swarm:** `docker stack ls`, `docker stack ps <nome>`

---

## 16. Migração Compose (bridge) → Swarm (overlay)

Resumo para uma VPS que já corria **edge** / **shared** / **apps** só com Compose:

1. **Janela de manutenção** breve ou aceitar paragem enquanto se trocam as redes.
2. Parar stacks na ordem inversa habitual: apps → **edge** (Traefik) → **shared** (último se quiseres minimizar tempo sem BD).
3. Remover redes **`infra_edge`** e **`infra_shared`** se ainda existirem como **bridge** (`docker network rm …` só sem contentores ligados).
4. Correr **`ci/swarm-bootstrap.sh`** com **`SWARM_ADVERTISE_ADDR`** definido.
5. Subir **shared**, **edge** e **apps** com os comandos das secções 8, 9 e 11 (ficheiros **`docker-stack.yml`**).
6. Subir **Jenkins** com **`docker compose up -d`** (rede `infra_edge` externa).
7. Confirmar volumes Docker (`docker volume ls`): os nomes devem alinhar com o projeto/stack (`infra-shared_…`, `infra-edge_…`). Se necessário, ajustar antes com cópia de dados (fora do âmbito deste doc).

---

## 17. Evoluções possíveis (não implementadas)

- Allowlist IP / VPN no dashboard Traefik
- Secrets centralizados (Vault, sops) em vez de `.env` nos hosts
- Vários nós Swarm (workers) e placement por constraints

Este documento substitui os antigos ficheiros por etapa (`01`–`07`), `convencoes-e-decisoes.md` e `versionamento-git.md`.
