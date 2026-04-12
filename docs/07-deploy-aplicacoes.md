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

## Jenkins (job **deploy-app**)

O ficheiro `ci/jenkins/DeployApp.Jenkinsfile` faz SSH para a VPS, corre `git pull` em `~/infra` e `./ci/deploy-app.sh` com o parâmetro **APP_SLUG**.

### 1. Plugin e variáveis

- Imagem Jenkins: inclui o plugin **SSH Agent** (`ssh-agent` no `plugins.txt`). Após alteração, `docker compose build` e `up -d` em `stacks/jenkins/`.
- No `stacks/jenkins/.env`, define **`DEPLOY_SSH_USER`** e **`DEPLOY_SSH_HOST`** (ex.: utilizador Linux da VPS e hostname ou IP acessível a partir do container Jenkins).

### 2. Credencial SSH

Em **Manage Jenkins → Credentials**, cria uma credencial do tipo **SSH Username with private key** com ID **`vps-deploy-ssh`** (a chave privada tem de permitir login na VPS como `DEPLOY_SSH_USER`).

### 3. Criar o job (uma vez)

**Opção A — Script Console** (como admin): cola o conteúdo de `ci/jenkins/seed-deploy-app-job.groovy` e executa. Ajusta o URL do Git se o remoto não for o público `lucaskaiut/infra`.

**Opção B — Manual:** **New Item** → *Pipeline* → **Pipeline script from SCM** → Git → branch `main` → *Script Path* `ci/jenkins/DeployApp.Jenkinsfile`.

### 4. Executar

**Build with Parameters** → `APP_SLUG` = `ematricula` (ou outro slug com `ci/apps/<slug>.sh`).

## Traefik e `DOMAIN`

Stacks que expõem hostname via Traefik devem usar **`${DOMAIN}`** no label `Host(\`...`)` e ter **`DOMAIN`** no `.env` da stack (alinhado ao domínio real). O Laravel continua a precisar de `APP_URL` e domínios em `SANCTUM_*` coerentes com esse hostname (ver `stacks/apps/ematricula/.env.example`).

## Referências

- `docs/04-etapa-4-ematricula-api.md` — detalhes da API eMatricula.
- `docs/06-etapa-6-jenkins.md` — Jenkins base e job `ci-smoke`.
