---
name: vps-infra-troubleshooting
description: Use when the user asks to diagnose VPS infrastructure issues in this repo, such as 5xx, bad gateway, TLS, routing, container health, Docker network, Swarm or Compose failures. Focus on infra layers first: DNS, Traefik, stack status, logs, networks, env interpolation, and shared services before blaming application code.
---

# VPS Infra Troubleshooting

Use this skill for incident triage in this repository.

## Goal

Find the failing infra layer quickly without changing application source code.

## Triage Order

1. Confirm the affected hostname, stack, and exact symptom.
2. Check container or service status before changing anything.
3. Validate the entrypoint layer:
   - DNS record
   - Traefik router and TLS
   - Public HTTP status
4. Validate the runtime layer:
   - container or service health
   - restart loops
   - recent logs
5. Validate dependencies:
   - `infra_edge`
   - `infra_shared`
   - MySQL / Redis reachability
6. Validate configuration:
   - `docker compose config`
   - missing env vars
   - wrong hostnames or labels
7. Only then conclude whether the failure is likely inside the app.

## Safe Checks

- `docker compose ps`
- `docker stack services <stack>`
- `docker logs --tail 100 <container>`
- `docker service logs --tail 100 <service>`
- `curl -I https://host`
- `docker compose config`
- `docker network inspect <network>`

## Repo Hints

- Edge lives in `stacks/edge/`
- Shared services live in `stacks/shared/`
- App stacks live in `stacks/apps/*/`
- Operational guidance lives in `docs/arquitetura.md`

## 404 em rotas Laravel (`/api/...`, etc.)

Se `curl` devolver **404** mas os cabeçalhos incluírem **`X-Powered-By: PHP`** (ou `Server: nginx` com resposta gerada pela app), o pedido **já chegou ao Laravel**: não é Traefik nem Nginx a “perder” o path. Comparar o que está **na imagem** com o repositório da app:

- `docker exec <container> sh -c "cd /var/www/html && su-exec www-data php artisan route:list --path=api"`
- `docker exec <container> cat /var/www/html/routes/api.php` (ou o ficheiro de rotas relevante)

Se a rota existir no `git` local mas **não** no contentor, o build em produção está **atrás do branch** (commit não fez push, ou deploy não correu após o push). A correção é **atualizar código da app e voltar a correr** `./ci/deploy-app.sh <slug>` — não é alteração de Nginx neste repositório.

Para health pública de stack, o padrão deste infra costuma ser **`/up`** (Laravel) nas labels Traefik, não um path arbitrário em `/api/*`, salvo a app o expor nas rotas versionadas.

## Common Findings

- `DOMAIN` or other vars missing because `docker compose` ran without the expected `--env-file`
- Traefik labels correct in Compose but wrong in Swarm because they belong under `deploy.labels`
- App depends on `mysql` or `redis` but is not attached to `infra_shared`
- Public URL, `APP_URL`, `WEBHOOK_URL`, `N8N_HOST`, or Jenkins URL inconsistent with Traefik hostname
- Service is healthy at container level but blocked by upstream app error; in that case report the logs and keep changes on the infra side only

## Output Style

- State the failing layer first
- Include the exact check that supports the conclusion
- If the app code looks broken, report symptoms and relevant logs, but do not patch the app here

