# Stack Financeiro Borcath (API Laravel)

Publica apenas a pasta `api` do monorepo
[financeiro-borcath](https://github.com/lucaskaiut/financeiro-borcath). O frontend
(`web/`) é hospedado em outro lugar.

## Domínios

- API: `https://financeiro-api.${DOMAIN}`
- Frontend: `https://financeiro.${DOMAIN}` (construído fora desta stack)

`DOMAIN=dborcath.com.br` no `.env` desta stack (alinhado ao padrão `vulcano`).

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** com MySQL na rede `infra_shared`.
- DNS `A` para `financeiro-api.dborcath.com.br` → IP da VPS.
- Base de dados `financeiro_borcath` + usuário com privilégios no MySQL compartilhado.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh financeiro-borcath
```

Faz build da imagem `local/financeiro-borcath-api:latest` (PHP 8.4 + Nginx + PHP-FPM)
e deploy via Swarm na stack `infra-app-financeiro-borcath`.

## Serviços desta stack

| Serviço | Função |
|---------|--------|
| `app`   | Nginx + PHP-FPM (API, TLS no Traefik), 2 réplicas, rolling `start-first` |
| `worker`| Fila (`queue:work` com driver database) |

MySQL fica em `stacks/shared/`, não aqui.

## Jenkins (webhook GitHub)

- Jenkinsfile: `ci/jenkins/DeployFinanceiroBorcathWebhook.Jenkinsfile`.
- Credencial Secret text ID **`financeiro-borcath-webhook-token`**.
- Deploy ocorre quando há mudanças em `api/` no push para `main`.
- URL do webhook: `https://jenkins.${DOMAIN}/generic-webhook-trigger/invoke?token=<segredo>`.
