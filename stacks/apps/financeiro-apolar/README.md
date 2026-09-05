# Stack Financeiro Apolar (API Laravel)

Publica apenas a pasta `api` do monorepo
[financeiro-apolar](https://github.com/lucaskaiut/financeiro-apolar). O frontend
(`web/`) é hospedado em outro lugar.

## Domínios

- API: `https://financeiro-apolar-api.${DOMAIN}`

`DOMAIN=noxtecnologias.com.br` no `.env` desta stack.

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** com MySQL na rede `infra_shared`.
- DNS `A` para `financeiro-apolar-api.noxtecnologias.com.br` → IP da VPS.
- Base de dados `financeiro_apolar` + usuário com privilégios no MySQL compartilhado.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh financeiro-apolar
```

## Jenkins (webhook GitHub)

- Jenkinsfile: `ci/jenkins/DeployFinanceiroApolarWebhook.Jenkinsfile`.
- Credencial Secret text ID **`financeiro-apolar-webhook-token`**.
- Deploy ocorre quando há mudanças em `api/` no push para `main`.
- URL do webhook: `https://jenkins.lucaskaiut.com.br/generic-webhook-trigger/invoke?token=<segredo>`.
