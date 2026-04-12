# Etapa 6 — Jenkins (job manual, sem CD)

## Objetivo

Jenkins a correr atrás do Traefik, com um job **ci-smoke** que faz `checkout` do repositório de infra + `echo`, **sem** deploy automático na VPS.

## Pré-requisitos

- Stack `edge` (Traefik) ativa e rede `infra_edge`.
- DNS: registo `jenkins.<DOMAIN>` apontando para a VPS (mesmo padrão das outras apps).
- Ficheiro `stacks/jenkins/.env` a partir de `.env.example`.
- A imagem customizada usa **`jenkins/jenkins:lts-jdk21`** (Java 21). O Java 17 deixou de ser suportado pelo Jenkins LTS; após mudar o `Dockerfile`, faz `docker compose build` e `up -d` na stack para aplicar.

## Variáveis

| Variável | Uso |
|----------|-----|
| `DOMAIN` | Host `jenkins.${DOMAIN}` no Traefik. |
| `JENKINS_URL` | URL pública (HTTPS); deve coincidir com o que o Traefik expõe. |
| `JENKINS_ADMIN_PASSWORD` | Utilizador `admin` no Jenkins. |
| `GITHUB_REPO_URL` | Repo a clonar no job (predefinição: infra). |
| `GITHUB_TOKEN` | PAT read-only (recomendado se o repo for privado). |
| `GITHUB_USERNAME` | Com PAT GitHub costuma funcionar `git` ou o teu username. |

Se **não** definires `GITHUB_TOKEN`, o job usa clone HTTPS **sem** credencial (adequado só para repositório **público**).

## Credencial `github-readonly`

Com `GITHUB_TOKEN` no `.env`, o script de arranque regista automaticamente uma credencial Jenkins com ID **`github-readonly`** (username + password = PAT), usada pelo passo `git` do pipeline.

Alternativa manual: no Jenkins, **Manage Jenkins → Credentials → (global) → Add** → *Username with password*, ID **`github-readonly`**.

## Subir a stack

Na VPS (ou localmente com Traefik e DNS):

```bash
cd stacks/jenkins
cp .env.example .env
# editar .env (password admin, JENKINS_URL, DOMAIN, opcional GITHUB_*)
docker compose build --no-cache
docker compose up -d
```

Abrir `https://jenkins.<DOMAIN>`, entrar como **admin** com `JENKINS_ADMIN_PASSWORD`.

## Job **ci-smoke**

Criado na **primeira** inicialização do volume Jenkins (init Groovy). Faz:

1. **Checkout** — branch `main` de `GITHUB_REPO_URL` (com ou sem `github-readonly`).
2. **Echo** — mensagem de smoke; não há deploy.

**Build now** deve ficar verde se o clone for bem-sucedido.

### Volume já existente

Os ficheiros em `init.groovy.d` só correm quando o `jenkins_home` é populado pela primeira vez. Se já tiveres um volume antigo **sem** o job:

- opção A: apagar o volume `infra-jenkins_jenkins_home` e voltar a subir (perde configuração Jenkins); ou  
- opção B: criar manualmente um pipeline com o mesmo script (copiar do ficheiro `stacks/jenkins/image/init.groovy.d/02-ci-smoke-job.groovy`).

### Atualizar o pipeline depois de mudar o repositório

O script do job **ci-smoke** fica guardado no Jenkins; alterações em `init.groovy.d` no Git **não** reaplicam sozinhas. Para alinhar com a versão atual do repositório: **ci-smoke → Configure**, edita o *Pipeline script* (remove blocos inválidos, por exemplo `options { timestamps() }` se não tiveres o plugin Timestamper) ou cola o conteúdo atualizado do ficheiro `stacks/jenkins/image/init.groovy.d/02-ci-smoke-job.groovy` (só a parte `pipeline { ... }`).

## Job **deploy-app** (CD por SSH)

O deploy para a VPS usa o ficheiro `ci/jenkins/DeployApp.Jenkinsfile` no repositório **infra**. Requer plugin **SSH Agent**, credencial **`vps-deploy-ssh`**, e variáveis **`DEPLOY_SSH_USER`** / **`DEPLOY_SSH_HOST`** no `.env` da stack Jenkins. Passo a passo: `docs/07-deploy-aplicacoes.md`.

## Segurança

- Não commits o `.env` (contém password e opcionalmente PAT).
- PAT: permissões mínimas (ex.: **Contents: Read-only** no repo).
- Jenkins não tem acesso ao Docker socket nesta etapa (sem CD).

## Validação

1. `docker compose ps` — container `infra_jenkins` em execução.
2. HTTPS em `JENKINS_URL` sem erro de certificado.
3. Login como admin.
4. Job **ci-smoke** → **Build Now** → build verde.
5. (Opcional) Job **deploy-app** → **Build with Parameters** após configurar SSH conforme `docs/07-deploy-aplicacoes.md`.
