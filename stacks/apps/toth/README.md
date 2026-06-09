# Stack Toth CRM (API Laravel — sem frontend)

Publica apenas a pasta `api` do repositório [toth](https://github.com/lucaskaiut/toth). O painel **web/** é deployado na **Vercel**; esta stack cobre API, filas, WebSocket (Reverb) e PostgreSQL/pgvector.

## Serviços

| Serviço | Função |
|---------|--------|
| `api` | PHP 8.4-FPM (Laravel) |
| `nginx` | HTTP público → `api:9000`, health `/up` |
| `worker` | `queue:work redis --queue=default,redis` |
| `reverb` | WebSocket Laravel Reverb (`:8081`) |
| `postgres-vector` | pgvector (RAG), rede interna |

MySQL e Redis vêm de `stacks/shared/` (`mysql`, `redis`).

## Hostnames públicos

| Host | Uso |
|------|-----|
| `toth-api.<DOMAIN>` | API REST HTTPS |
| `toth-ws.<DOMAIN>` | WebSocket WSS (Reverb) |

DNS: registos **A** para ambos apontando à VPS.

## Variáveis críticas

- **Backend Reverb:** `REVERB_HOST=reverb`, `REVERB_PORT=8081`, `REVERB_SCHEME=http` (rede interna).
- **Vercel (build do web/):** `VITE_REVERB_HOST=toth-ws.<DOMAIN>`, `VITE_REVERB_PORT=443`, `VITE_REVERB_SCHEME=https`, `VITE_REVERB_APP_KEY` = mesmo `REVERB_APP_KEY` da API.
- `BROADCAST_CONNECTION=reverb`, `QUEUE_CONNECTION=redis`, `SESSION_DRIVER=database`.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh toth
```

Bootstrap no arranque do `api`: `migrate`, `vector:migrate` (se existir), `config/route/view:cache`.

Após alterar `.env` (ex.: `WHATSAPP_API_KEY`), reaplicar a stack para o Swarm injetar as variáveis nos contentores:

```bash
cd ~/infra/stacks/apps/toth
docker compose -f docker-stack.yml --env-file .env config | sed '/^name:/d' > /tmp/toth.yml
docker stack deploy -c /tmp/toth.yml infra-app-toth
```

`WHATSAPP_API_KEY` deve coincidir com `AUTHENTICATION_API_KEY` da stack Evolution API.

## Jenkins

`ci/jenkins/DeployTothWebhook.Jenkinsfile` — credencial **`toth-webhook-token`**.

## Monitoramento

Uptime Kuma: `GET https://toth-api.<DOMAIN>/up` → 200.
