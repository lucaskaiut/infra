# Template de nova aplicação

Este diretório não é deployado diretamente: serve de modelo para criar `stacks/apps/<slug>/`.

## Passos

1. Copiar a pasta: `cp -r stacks/apps/_template stacks/apps/<slug>` (ex.: `meu-produto`).
2. Dentro de `stacks/apps/<slug>/`, substituir **todas** as ocorrências de `myservice` pelo seu subdomínio desejado (o mesmo valor em `name`, `container_name`, labels e hostname). O DNS deve ter um registo `A` (ou CNAME) para `<slug>.<DOMAIN>` apontando para a VPS.
3. Ajustar `image`, `container_name`, portas internas e labels Traefik conforme a sua aplicação real (este modelo usa `whoami` na porta 80).
4. Subir com `docker compose --env-file ../../../.env up -d` a partir da pasta da nova app (três níveis abaixo da raiz do repo, como em `demo`).
5. Validar: `https://<slug>.<DOMAIN>` com TLS e resposta esperada.
6. **CI (opcional):** para notificar o n8n após deploy, cria `ci/apps/<slug>.sh` (com `APP_GIT_SUBDIR` se o clone não for só `<slug>/`) e usa o padrão do ficheiro `ci/jenkins/DeployApp.Jenkinsfile.example` (`post { always { ... notify-n8n-deploy.sh } }`). Variáveis: `N8N_DEPLOY_WEBHOOK_URL` ou `N8N_API_URL` no `.env` do Jenkins / raiz do infra.

## Convenções

- Rede externa obrigatória: `infra_edge` (criada pela stack `stacks/edge`).
- Se a app precisar de MySQL ou Redis, ligue também a rede **`infra_shared`** (stack `stacks/shared/`) e use `DB_HOST=mysql`, `REDIS_HOST=redis`, com prefixos Redis por app. Ver `docs/arquitetura.md` (secção *Stack shared*).
- Nomes de router Traefik únicos em todo o host (prefixe com o slug da app).
- `exposedByDefault: false` no Traefik: mantenha `traefik.enable=true` nos serviços que devem ser públicos.
