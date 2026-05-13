# Plutão API (Laravel)

Stack **Swarm** em produção (`infra-app-plutao`). Imagem `local/plutao-api:latest` construída a partir da pasta `api/` do repositório `lucaskaiut/plutao`.

## Domínio público

`https://plutao-api.${DOMAIN}` via Traefik.

## Base de dados partilhada

MySQL e Redis estão na stack `infra-shared`. É necessário que exista a base **`plutao`** e que o utilizador definido em `stacks/shared/.env` (`MYSQL_USER` / `MYSQL_PASSWORD`) tenha permissões sobre essa base (criar com utilizador `root` no contentor MySQL se ainda não existir).

## Deploy

```bash
./ci/deploy-app.sh plutao
```

## Jenkins (webhook GitHub)

- Jenkinsfile: `ci/jenkins/DeployPlutaoWebhook.Jenkinsfile`
- Credencial Secret text com ID **`plutao-webhook-token`** (valor = parâmetro `token=` na URL do webhook).
- Chave SSH de **deploy** (read-only) para clonar o repo: `stacks/jenkins/keys-plutao/id_ed25519` (ver `.gitignore`; não versionar a chave privada).
- URL do webhook: `https://jenkins.<DOMAIN>/generic-webhook-trigger/invoke?token=<segredo>`

Criação do job na VPS (com Jenkins a correr):

```bash
cd ~/infra
./ci/jenkins/create-webhook-job-from-template.sh \
  deploy-ematricula-webhook \
  deploy-plutao-webhook \
  ci/jenkins/DeployPlutaoWebhook.Jenkinsfile \
  plutao-webhook-token
```

## Clonar o código da app no host/Jenkins

Por defeito o clone usa **HTTPS** (`https://github.com/lucaskaiut/plutao.git`), suficiente para o repo público.

Opcional (repo privado ou preferência SSH): coloca `id_ed25519` e `id_ed25519.pub` em `stacks/jenkins/keys-plutao/`, regista a **chave pública** como *Deploy key* no GitHub **plutao**, e em `ci/apps/plutao.sh` define `APP_GIT_REMOTE="git@github.com:lucaskaiut/plutao.git"` e `APP_GIT_USE_SSH=1`.
