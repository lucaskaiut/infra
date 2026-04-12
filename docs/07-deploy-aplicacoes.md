# Deploy de aplicações (script + Jenkins)

## Objetivo

- **eMatricula** (e novas apps) deployadas com um fluxo repetível: atualizar código (quando há repositório de app), `docker compose build` e `up -d`.
- **Generalização:** cada app tem um ficheiro pequeno em `ci/apps/<slug>.sh`; o orquestrador é `ci/deploy-app.sh <slug>`.

## Script na VPS

Na raiz do clone de **infra** (ex.: `~/infra`):

```bash
chmod +x ci/deploy-app.sh
./ci/deploy-app.sh ematricula
```

O script:

1. Carrega `ci/apps/ematricula.sh` (variáveis `APP_COMPOSE_DIR`, opcionalmente `APP_GIT_*`).
2. Se `APP_GIT_SUBDIR` e `APP_GIT_REMOTE` estiverem definidos, garante clone/`git pull --ff-only` nessa pasta (relativa à stack).
3. Corre `docker compose build` e `docker compose up -d` (com **`--wait`** quando o Docker Compose do host suporta, para alinhar arranque com healthchecks).

**Pré-requisitos na VPS:** utilizador com permissão para `docker compose`; ficheiro `.env` da stack já configurado; rede `infra_edge` e `infra_shared` conforme as etapas anteriores.

## Nova aplicação

1. Criar `stacks/apps/<slug>/` (podes partir de `stacks/apps/_template/` ou do modelo eMatricula).
2. Copiar `ci/apps/_template.sh.example` para `ci/apps/<slug>.sh` e preencher:
   - `APP_COMPOSE_DIR` — caminho relativo à raiz do repo infra (ex.: `stacks/apps/meu-slug`).
   - Se a app tiver código noutro repositório: `APP_GIT_SUBDIR`, `APP_GIT_REMOTE`, `APP_GIT_BRANCH`.
   - Se for só imagem/compose sem clone: deixa `APP_GIT_SUBDIR` e `APP_GIT_REMOTE` vazios.
3. Commit no repositório **infra**; na VPS, `git pull` e `./ci/deploy-app.sh <slug>`.

## Deploy automático eMatricula (push em `api/`)

Objetivo: ao fazer **push** no repositório **`lucaskaiut/ematricula`** na branch **`main`**, com alterações sob a pasta **`api/`**, o Jenkins corre o mesmo fluxo que `./ci/deploy-app.sh ematricula` (pull do **infra** montado + pull do monorepo + build + `up`).

### O que precisas de fazer (uma vez)

1. **Credencial no Jenkins** (obrigatório **antes** de guardar o job, se o Jenkins validar o trigger):
   - **Manage Jenkins → Credentials → (global) → Add credentials**
   - Tipo: **Secret text**
   - **Secret:** uma cadeia longa e aleatória (ex.: `openssl rand -hex 32`)
   - **ID:** exatamente **`ematricula-webhook-token`** (tem de coincidir com o `tokenCredentialId` no Jenkinsfile)

2. **Job no Jenkins**
   - **Opção A:** **Manage Jenkins → Script Console**, cola e executa o conteúdo de `ci/jenkins/seed-deploy-ematricula-webhook-job.groovy` (ajusta o URL Git se o remoto de **infra** não for o público).
   - **Opção B:** **New Item** → nome `deploy-ematricula-webhook` → *Pipeline* → **Pipeline script from SCM** → repositório **infra**, branch `main`, *Script Path* **`ci/jenkins/DeployEmatriculaWebhook.Jenkinsfile`**.

3. **Webhook no GitHub** (repositório **ematricula**, não o infra):
   - **Settings → Webhooks → Add webhook**
   - **Payload URL:** `https://jenkins.<TEU_DOMAIN>/generic-webhook-trigger/invoke?token=` + o **mesmo** segredo que guardaste na credencial (sem espaços).
   - **Content type:** `application/json`
   - **Events:** “Just the push event”
   - Guarda. Usa **HTTPS** para o token não ir em claro em redes inseguras.

4. **Primeiro build:** no Jenkins, corre manualmente o job **`deploy-ematricula-webhook`** uma vez (“Build Now”) para validar permissões e caminhos.

### Comportamento do pipeline

- **Webhook:** só corre deploy se `ref` for `refs/heads/main`, o repositório for `lucaskaiut/ematricula` e existir pelo menos um ficheiro alterado sob **`api/`** (incluindo `api` na raiz do monorepo).
- **Build manual** pelo Jenkins: **ignora** esses filtros e corre sempre o deploy (útil para forçar uma atualização).
- **Commits** sem ficheiros em `api/`: o build fica **`NOT_BUILT`** (não há deploy).

### Sobre “zero downtime”

Com **um** contentor `app` por stack e **`docker compose up -d`** após rebuild da imagem, o Docker substitui o contentor: costuma haver **alguns segundos** em que o Traefik pode falhar ou obter erros enquanto o novo processo sobe. O script usa **`docker compose up -d --wait`** quando disponível, e o serviço `app` tem **healthcheck** e **`stop_grace_period`** para encerrar com mais margem — isto **reduz** janelas de erro, mas **não** é rolling update com duas réplicas em paralelo.

**Zero downtime estrito** exigiria, por exemplo: várias réplicas do mesmo serviço sem `container_name`, orquestrador com rolling update (Swarm/Kubernetes), ou blue/green com dois stacks. Isso fica fora do escopo atual do Compose simples na VPS.

## Jenkins (job **deploy-app**, mesma VPS)

O Jenkins corre **no mesmo host** que as aplicações. O pipeline **não** usa SSH: executa `git pull` e `./ci/deploy-app.sh` dentro do diretório **`/infra-deploy`**, que é o clone de **infra** no host montado em modo leitura-escrita no container.

### 1. Imagem e Docker

A imagem customizada (`stacks/jenkins/image/Dockerfile`) inclui o binário **`docker`** e o plugin **`docker compose`** (v2), para o job invocar `docker compose build` / `up` no daemon do host.

### 2. Compose da stack Jenkins (`stacks/jenkins/docker-compose.yml`)

- **`INFRA_HOST_PATH`** — caminho **absoluto** no host para o repositório **infra** (o mesmo que usas em `~/infra` na VPS). Ex.: `/home/deploy/infra`.
- **`DOCKER_GID`** — GID numérico do grupo **`docker`** no host (o utilizador que corre os containers precisa de poder falar com o socket). Obténs com: `getent group docker | cut -d: -f3`.
- **Volume** `/var/run/docker.sock` — o Jenkins usa o Docker do host para os builds/deploys.

**Implicação de segurança:** quem controla o Jenkins (ou um job malicioso) pode, via socket, pedir ao Docker do host ações equivalentes a elevado privilégio. Adequado em VPS dedicada a esta infra; evita expor o Jenkins publicamente sem autenticação forte.

### 3. Autenticação `git pull` no mount

O `git pull` corre **dentro** do container sobre os ficheiros montados. Repositório **público** em HTTPS costuma funcionar sem credenciais extra. Se **infra** for **privado**, configura credenciais (PAT no remoto só no host, ou credencial Git no Jenkins e ajusta o job para usar `withCredentials` / checkout em alternativa ao pull no mount — ver notas da equipa).

Garante que o UID do utilizador **`jenkins`** no container (normalmente `1000`) consegue escrever em `.git` e no working tree do mount, ou alinha dono dos ficheiros no host com esse UID.

### 4. Criar o job **deploy-app** (manual com parâmetro)

**Opção A — Script Console:** `ci/jenkins/seed-deploy-app-job.groovy`

**Opção B — Manual:** **Pipeline script from SCM** → *Script Path* `ci/jenkins/DeployApp.Jenkinsfile`.

### 5. Executar **deploy-app**

**Build with Parameters** → `APP_SLUG` = `ematricula` (ou outro slug com `ci/apps/<slug>.sh`).

Após alterar `Dockerfile`, `docker-compose.yml` ou `plugins.txt` do Jenkins: `docker compose build` e `up -d` em `stacks/jenkins/`.

## Traefik e `DOMAIN`

Stacks que expõem hostname via Traefik devem usar **`${DOMAIN}`** no label `Host(\`...`)` e ter **`DOMAIN`** no `.env` da stack (alinhado ao domínio real). O Laravel continua a precisar de `APP_URL` e domínios em `SANCTUM_*` coerentes com esse hostname (ver `stacks/apps/ematricula/.env.example`).

## Referências

- `docs/04-etapa-4-ematricula-api.md` — detalhes da API eMatricula.
- `docs/06-etapa-6-jenkins.md` — Jenkins base e job `ci-smoke`.
