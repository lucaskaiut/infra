# Etapa 3 — Template para nova aplicação

## Objetivo

Padronizar a criação de stacks em `stacks/apps/<slug>/` com a rede `infra_edge` e labels Traefik coerentes.

## Localização

- Modelo: `stacks/apps/_template/` (`docker-compose.yml` + `README.md`).
- Aplicação de referência já deployada: `stacks/apps/demo/`.

## Fluxo resumido

1. `cp -r stacks/apps/_template stacks/apps/<slug>`
2. Substituir `myservice` pelo slug real (hostname `https://<slug>.<DOMAIN>`).
3. Trocar imagem, portas e labels conforme o serviço real.
4. DNS para `<slug>.<DOMAIN>`.
5. `docker compose --env-file ../../../.env up -d` na pasta da app.
6. Para deploy automatizado com o mesmo padrão da eMatricula: ficheiro `ci/apps/<slug>.sh` e `docs/07-deploy-aplicacoes.md`.

## Validação

- `docker compose --env-file ../../../.env ps` mostra o container **Up**.
- `https://<slug>.<DOMAIN>` responde com TLS válido e a aplicação esperada.

## Versionamento

- Versionar apenas o `_template` e cada app real em `stacks/apps/<slug>/`.
- Não versionar segredos da aplicação (usar `.env` na raiz do repo de infra ou mecanismo próprio).
