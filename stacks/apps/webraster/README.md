# Stack Webraster (API Laravel)

Publica apenas a pasta `api` do monorepo
[rastreamento-veicular](https://github.com/lucaskaiut/rastreamento-veicular). O frontend
(`web/`) é hospedado em outro lugar.

## Domínios

- API: `https://webraster-api.${DOMAIN}`
- Frontend: `https://webraster.${DOMAIN}` (construído fora desta stack)

`DOMAIN=noxtecnologias.com.br` no `.env` desta stack.

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** com MySQL na rede `infra_shared`.
- DNS `A` para `webraster-api.noxtecnologias.com.br` → IP da VPS.
- Base de dados `webraster` + usuário com privilégios no MySQL compartilhado.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh webraster
```

Faz build da imagem `local/webraster-api:latest` (PHP 8.4 + Nginx + PHP-FPM)
e deploy via Swarm na stack `infra-app-webraster`.

## Serviços desta stack

| Serviço     | Função |
|-------------|--------|
| `app`       | Nginx + PHP-FPM (API, TLS no Traefik), 2 réplicas, rolling `start-first` |
| `worker`    | Fila (`queue:work` com driver database); restart `any` (o worker sai após `--max-time`) |
| `scheduler` | `schedule:run` a cada 60s (faturação, status de faturas, suspensão, dispositivos offline) |

Uploads em `storage/app/public` ficam no volume Swarm `webraster_storage`, partilhado pelas réplicas da `app`. MySQL fica em `stacks/shared/`, não aqui.

## Jenkins (webhook GitHub)

- Jenkinsfile: `ci/jenkins/DeployWebrasterWebhook.Jenkinsfile`.
- Credencial Secret text ID **`webraster-webhook-token`**.
- Deploy ocorre quando há mudanças em `api/` no push para `main`.
- URL do webhook: `https://jenkins.lucaskaiut.com.br/generic-webhook-trigger/invoke?token=<segredo>`.
