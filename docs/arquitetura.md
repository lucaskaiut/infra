# Arquitetura e operação da infraestrutura

Documento único: visão da plataforma Docker na VPS, decisões técnicas, como subir e corrigir problemas. Público-alvo: equipa que mantém **infra** (repositório separado do código das aplicações).

---

## 1. Papel deste repositório

| Repositório | Conteúdo |
|-------------|----------|
| **infra** (este) | Traefik, redes, MySQL/Redis partilhados, Compose por app, Jenkins, scripts `ci/`, documentação operacional |
| **Aplicações** (ex.: `ematricula`) | Código, testes, lógica de negócio. A imagem da API eMatricula constrói-se a partir de `ematricula/api` no monorepo; alterações de produto fazem-se **lá**, não na infra |

---

## 2. Mapa de pastas

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Traefik (TLS, roteamento), rede **`infra_edge`** |
| `stacks/shared/` | MySQL + Redis, rede **`infra_shared`** |
| `stacks/apps/<slug>/` | Uma stack Compose por aplicação (ex.: `demo`, `ematricula`) |
| `stacks/apps/_template/` | Modelo para copiar ao criar nova app simples |
| `stacks/jenkins/` | Jenkins (CI/CD), imagem customizada, CasC, init Groovy |
| `ci/` | `deploy-app.sh`, `ci/apps/<slug>.sh`, Jenkinsfiles em `ci/jenkins/` |

---

## 3. Redes e nomenclatura

- **`infra_edge`** — Criada pela stack `edge`. Traefik e qualquer serviço com HTTP público ligam-se aqui.
- **`infra_shared`** — Criada pela stack `shared`. Apps que precisam de BD/cache ligam-se como rede **external**; resolvem **`mysql`** e **`redis`** pelos nomes dos serviços no Compose do shared.
- **Compose:** `name` explícito por projeto (`infra-edge`, `infra-app-<slug>`, `infra-shared`, `infra-jenkins`).
- **Containers:** Traefik e workers com nome fixo quando definido no Compose; a API eMatricula em produção usa **2 réplicas** do serviço `app` (nomes gerados, ex. `infra-app-ematricula-app-1`, `…-app-2`) atrás do mesmo balanceador Traefik.

**Regra:** um par MySQL + Redis para todas as apps; isolamento em Redis com **prefixos** (ex. Laravel `REDIS_PREFIX`).

---

## 4. Decisões técnicas

| Área | Escolha | Motivo |
|------|---------|--------|
| Proxy / TLS | Traefik **v3.6+** | Labels Docker, ACME; evita *client API 1.24 too old* com Docker Engine 29+ |
| Orquestração | Docker Compose por stack | Simples numa VPS; uma pasta por app |
| ACME | `tlsChallenge` | Menos conflito com redirecionamentos HTTP→HTTPS do que HTTP-01 na porta 80 em alguns cenários |
| Deploy por app | `ci/deploy-app.sh <slug>` + `ci/apps/<slug>.sh` | Configuração mínima por app; Jenkins na mesma VPS monta o clone **infra** e o **socket Docker** (sem SSH no pipeline de deploy) |
| Jenkins | Imagem `lts-jdk21`, CasC, init Groovy | Java 21 exigido pelo Jenkins LTS atual; job `ci-smoke` na primeira subida do volume |

**Traefik (segurança):** `exposedByDefault: false`; só entra no proxy quem tiver `traefik.enable=true`. Socket Docker no Traefik em **read-only** onde aplicável. Jenkins usa o socket **read-write** para `docker compose` — implica risco elevado se o Jenkins for comprometido; usar só em VPS dedicada, HTTPS forte e password admin forte.

---

## 5. Ordem de arranque na VPS

1. **edge** — cria `infra_edge`.
2. **shared** — cria `infra_shared`, MySQL e Redis.
3. **apps** — cada uma com `.env` próprio; as que têm tráfego público + BD precisam de **duas** redes (`edge` + `shared_data`).
4. **jenkins** — depois das anteriores se precisares de webhooks/deploy automatizado.

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

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
```

- Certificados Let's Encrypt; e-mail ACME via variável oficial do Traefik no Compose (fiável vs expandir `${ACME_EMAIL}` dentro de YAML estático montado).
- Se os logs mostrarem *client version 1.24 is too old*: `pull` + `up -d` com imagem Traefik **v3.6+**.

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

---

## 9. Stack shared (MySQL + Redis)

```bash
cd ~/infra/stacks/shared
cp .env.example .env
docker compose --env-file .env up -d
```

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

**Primeira subida:**

```bash
cd ~/infra/stacks/apps/ematricula
git clone https://github.com/lucaskaiut/ematricula.git ematricula
cp .env.example .env
docker compose build && docker compose up -d
```

- `DB_HOST=mysql`, `REDIS_HOST=redis`, credenciais DB alinhadas ao **shared**.
- Primeiro arranque do `app` pode correr migrações (`migrate --force`).
- TLS termina no Traefik; a imagem envia `HTTPS` / `X-Forwarded-Proto` ao PHP conforme necessário.

**Atualizar / deploy:**

```bash
cd ~/infra && ./ci/deploy-app.sh ematricula
```

O serviço `app` tem **healthcheck** e **`stop_grace_period`** para encerramento mais suave. Com um único réplica e `docker compose up` após rebuild, pode haver **segundos** de indisponibilidade durante a troca do contentor; `docker compose up -d --wait` (quando suportado) ajuda a alinhar com healthchecks. Zero downtime estrito exigiria réplicas múltiplas ou orquestrador com rolling update.

---

## 12. Jenkins (`stacks/jenkins/`)

### Imagem

- Base `jenkins/jenkins:lts-jdk21`.
- Plugins: `configuration-as-code`, `git`, `workflow-aggregator`, `credentials-binding`, `ssh-credentials`, `generic-webhook-trigger`.
- **Docker CLI** + **docker compose** v2 na imagem para jobs que falam com o daemon do host.
- CasC em `image/casc/jenkins.yaml`; init Groovy em `image/init.groovy.d/` (credencial GitHub opcional, job **ci-smoke** na **primeira** criação do volume).

### Compose

- Volume `jenkins_home`.
- Mount **`${INFRA_HOST_PATH}:/infra-deploy:rw`** — mesmo clone **infra** que na VPS.
- **`/var/run/docker.sock`** + **`group_add: ${DOCKER_GID}`** — GID do grupo `docker` no host (`getent group docker | cut -d: -f3`).

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
- **`ci/deploy-app.sh <slug>`:** carrega o `.sh`, faz `git pull` no subdiretório da app se configurado, `docker compose build`, `docker compose up -d` (com **`--wait`** se disponível).
- Modelo vazio: `ci/apps/_template.sh.example`.

---

## 14. Versionamento em Git

**Versionar:** `stacks/`, `ci/`, `docs/`, `README.md`, `.env.example`, `.gitignore`, exemplos de segredos (`*.example`).

**Não versionar:** `.env` com segredos, `stacks/shared/.env`, `stacks/jenkins/.env`, `stacks/apps/*/.env`, `stacks/edge/secrets/dashboard.htpasswd`, `acme.json` em bind mount, chaves SSH, tokens Jenkins, credenciais de registry, clones de aplicações em pastas gitignored (ex.: `ematricula/` dentro da stack).

**Produção:** `.env` no servidor com permissões restritas (`chmod 600`); evoluir para Vault/sops quando fizer sentido.

---

## 15. Checklist rápido de diagnóstico

1. **Redes:** `docker network ls | grep infra_`
2. **Ordem:** edge → shared → apps → jenkins
3. **Compose:** sempre `--env-file` correto ou `.env` na pasta do projeto
4. **Traefik:** labels `traefik.enable=true`, host `*.${DOMAIN}`, certresolver
5. **App com BD:** app na rede `infra_shared`, variáveis DB/Redis corretas
6. **Jenkins deploy:** `INFRA_HOST_PATH`, `DOCKER_GID`, mount e socket ativos; `docker exec infra_jenkins docker ps` funciona
7. **Webhook:** credencial ID exata `ematricula-webhook-token`, URL com mesmo token, branch `main`, paths `api/`

---

## 16. Evoluções possíveis (não implementadas)

- Allowlist IP / VPN no dashboard Traefik
- Rolling update real (Swarm/Kubernetes ou réplicas sem `container_name`)
- Secrets centralizados (Vault, sops)

Este documento substitui os antigos ficheiros por etapa (`01`–`07`), `convencoes-e-decisoes.md` e `versionamento-git.md`.
