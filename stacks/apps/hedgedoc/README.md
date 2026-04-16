# Stack HedgeDoc

Editor colaborativo de Markdown em `https://docs.${DOMAIN}` via Traefik.

## Versões

- HedgeDoc: `quay.io/hedgedoc/hedgedoc:1.10.7`
- PostgreSQL: `postgres:17.7-alpine`

## Variáveis

Copie `.env.example` para `.env` nesta pasta e ajuste:

- `DOMAIN`: domínio-base do host, resultando em `docs.<DOMAIN>`
- `HEDGEDOC_DB_PASSWORD`: senha do utilizador `hedgedoc` no Postgres
- `HEDGEDOC_SESSION_SECRET`: segredo de sessão (cookie signing). Se não definido, o HedgeDoc gera um novo a cada start e derruba sessões ativas.

## Política de acesso (deste deploy)

- `allowEmailRegister`: desativado (criação de contas via UI)
- `allowAnonymous`: desativado (uso anónimo)

## Deploy manual

Na raiz do `infra`, faça o deploy da stack:

```bash
cd ~/infra/stacks/apps/hedgedoc
docker compose -f docker-stack.yml --env-file .env config | sed '/^name:/d' >/tmp/hedgedoc.rendered.yml
docker stack deploy -c /tmp/hedgedoc.rendered.yml infra-app-hedgedoc
```

Depois valide:

```bash
docker service ls | grep hedgedoc
curl -I https://docs.${DOMAIN}
```

## CI/CD

Esta stack **não** inclui Jenkins/webhook. O deploy é manual por decisão operacional.
