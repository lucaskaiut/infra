# Vulcano API (Laravel)

Stack **Swarm** em produção (`infra-app-vulcano`). Imagem `local/vulcano-api:latest` construída a partir da pasta `api/` do monorepo [lucaskaiut/vulcano](https://github.com/lucaskaiut/vulcano) (o frontend `web/` é ignorado — hospedado noutro sítio).

## Domínio público

`https://vulcano-api.${DOMAIN}` via Traefik.

## Base de dados partilhada

MySQL e Redis estão na stack `infra-shared`. É necessário que exista a base **`vulcano`** e que o utilizador definido em `stacks/shared/.env` (`MYSQL_USER` / `MYSQL_PASSWORD`) tenha permissões sobre essa base.

## Deploy

```bash
./ci/deploy-app.sh vulcano
```

## Jenkins (webhook GitHub)

- Jenkinsfile: `ci/jenkins/DeployVulcanoWebhook.Jenkinsfile`
- Credencial Secret text com ID **`vulcano-webhook-token`** (valor = parâmetro `token=` na URL do webhook).
- Chave SSH de **deploy** (read-only) para clonar o repo: `stacks/jenkins/keys-vulcano/id_ed25519` (ver `.gitignore`; não versionar a chave privada).
- URL do webhook: `https://jenkins.<DOMAIN>/generic-webhook-trigger/invoke?token=<segredo>`

Criação do job na VPS (com Jenkins a correr):

```bash
cd ~/infra
./ci/jenkins/create-webhook-job-from-template.sh \
  deploy-ematricula-webhook \
  deploy-vulcano-webhook \
  ci/jenkins/DeployVulcanoWebhook.Jenkinsfile \
  vulcano-webhook-token
```

## Uptime Kuma

Monitor HTTP: `GET https://vulcano-api.<DOMAIN>/api/health` → 200 (quando a rota existir na app).
