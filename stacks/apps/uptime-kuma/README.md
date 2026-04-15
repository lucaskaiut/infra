# Stack Uptime Kuma

Painel de monitoramento em `https://uptime.${DOMAIN}` via Traefik.

## Versão

- Imagem oficial: `louislam/uptime-kuma:2.2.1`

## Variáveis

Copie `.env.example` para `.env` nesta pasta e ajuste:

- `DOMAIN`: domínio-base do host, resultando em `uptime.<DOMAIN>`
- `UPTIME_KUMA_ADMIN_USERNAME`: utilizador inicial desejado
- `UPTIME_KUMA_ADMIN_PASSWORD`: senha inicial desejada

As duas variáveis de admin são usadas apenas no bootstrap inicial automatizado; não são lidas pela imagem do Uptime Kuma.

## Deploy manual

Na raiz do `infra`, faça o deploy da stack:

```bash
cd ~/infra/stacks/apps/uptime-kuma
docker compose -f docker-stack.yml --env-file .env config | sed '/^name:/d' >/tmp/uptime-kuma.rendered.yml
docker stack deploy -c /tmp/uptime-kuma.rendered.yml infra-app-uptime-kuma
```

Depois valide:

```bash
docker service ls | grep uptime-kuma
curl -I https://uptime.${DOMAIN}
```

## CI/CD

Esta stack **não** inclui Jenkins/webhook. O deploy é manual por decisão operacional.
