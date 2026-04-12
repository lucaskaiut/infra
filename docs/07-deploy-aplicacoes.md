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
3. Corre `docker compose build` e `docker compose up -d` na pasta da stack.

**Pré-requisitos na VPS:** utilizador com permissão para `docker compose`; ficheiro `.env` da stack já configurado; rede `infra_edge` e `infra_shared` conforme as etapas anteriores.

## Nova aplicação

1. Criar `stacks/apps/<slug>/` (podes partir de `stacks/apps/_template/` ou do modelo eMatricula).
2. Copiar `ci/apps/_template.sh.example` para `ci/apps/<slug>.sh` e preencher:
   - `APP_COMPOSE_DIR` — caminho relativo à raiz do repo infra (ex.: `stacks/apps/meu-slug`).
   - Se a app tiver código noutro repositório: `APP_GIT_SUBDIR`, `APP_GIT_REMOTE`, `APP_GIT_BRANCH`.
   - Se for só imagem/compose sem clone: deixa `APP_GIT_SUBDIR` e `APP_GIT_REMOTE` vazios.
3. Commit no repositório **infra**; na VPS, `git pull` e `./ci/deploy-app.sh <slug>`.

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

### 4. Criar o job (uma vez)

**Opção A — Script Console** (como admin): cola o conteúdo de `ci/jenkins/seed-deploy-app-job.groovy` e executa. Ajusta o URL do Git se o remoto não for o público `lucaskaiut/infra`.

**Opção B — Manual:** **New Item** → *Pipeline* → **Pipeline script from SCM** → Git → branch `main` → *Script Path* `ci/jenkins/DeployApp.Jenkinsfile`.

### 5. Executar

**Build with Parameters** → `APP_SLUG` = `ematricula` (ou outro slug com `ci/apps/<slug>.sh`).

Após alterar `Dockerfile`, `docker-compose.yml` ou `plugins.txt` do Jenkins: `docker compose build` e `up -d` em `stacks/jenkins/`.

## Traefik e `DOMAIN`

Stacks que expõem hostname via Traefik devem usar **`${DOMAIN}`** no label `Host(\`...`)` e ter **`DOMAIN`** no `.env` da stack (alinhado ao domínio real). O Laravel continua a precisar de `APP_URL` e domínios em `SANCTUM_*` coerentes com esse hostname (ver `stacks/apps/ematricula/.env.example`).

## Referências

- `docs/04-etapa-4-ematricula-api.md` — detalhes da API eMatricula.
- `docs/06-etapa-6-jenkins.md` — Jenkins base e job `ci-smoke`.
