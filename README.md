# Infraestrutura Docker (VPS Ubuntu)

Repositório de infraestrutura: proxy de borda, redes compartilhadas e stacks por aplicação, preparado para CI/CD (Jenkins + GitHub) nas etapas seguintes.

## Mapa do repositório

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Borda: Traefik, TLS, roteamento por hostname |
| `stacks/apps/*/` | Uma pasta por aplicação (compose próprio, rede `infra_edge` externa) |
| `stacks/apps/_template/` | Modelo para copiar ao criar uma nova app |
| `stacks/shared/` | MySQL + Redis partilhados (rede `infra_shared`) |
| `stacks/jenkins/` | Jenkins (CI manual, job `ci-smoke`, sem CD) |
| `ci/` | Deploy por app (`deploy-app.sh`, configs em `ci/apps/`, Jenkinsfile em `ci/jenkins/`) |
| `docs/` | Passos por etapa, convenções e versionamento |

## Ordem das etapas

1. **Etapa 1 — Fundação** (`docs/01-etapa-1-fundacao.md`): Traefik + app demo (HTTPS).
2. **Etapa 2 — Dashboard** (`docs/02-etapa-2-dashboard-auth.md`): Basic Auth no dashboard Traefik.
3. **Etapa 3 — Template** (`docs/03-etapa-3-template-nova-app.md`): modelo `stacks/apps/_template/` para novas apps.
4. **Serviços partilhados** (`docs/05-servicos-compartilhados.md`, `stacks/shared/`): MySQL + Redis para todas as apps.
5. **Etapa 4 — eMatricula API** (`docs/04-etapa-4-ematricula-api.md`, `stacks/apps/ematricula/`): Laravel 13, Horizon, scheduler (usa shared).
6. **Etapa 6 — Jenkins** (`docs/06-etapa-6-jenkins.md`, `stacks/jenkins/`): CI manual (checkout + echo), credencial GitHub opcional.
7. **Deploy de apps** (`docs/07-deploy-aplicacoes.md`, `ci/`): script `deploy-app.sh`, jobs Jenkins **deploy-app** e **deploy-ematricula-webhook** (push em `api/` no repo ematricula).
8. *Próximas:* zero downtime, webhooks GitHub, CD mais fino.

Avance etapa a etapa e valide cada documento antes de seguir.

## Variáveis de ambiente

Copie `.env.example` para `.env` na raiz do repositório. Em cada pasta de stack, use `docker compose --env-file …` em **todos** os subcomandos que leem o Compose (`up`, `ps`, `down`, …), ou um link simbólico `.env` → raiz, conforme `docs/01-etapa-1-fundacao.md`.

## Documentação

- `docs/01-etapa-1-fundacao.md` — Etapa 1
- `docs/02-etapa-2-dashboard-auth.md` — Etapa 2
- `docs/03-etapa-3-template-nova-app.md` — Etapa 3
- `docs/04-etapa-4-ematricula-api.md` — Etapa 4 (API eMatricula)
- `docs/05-servicos-compartilhados.md` — MySQL/Redis partilhados
- `docs/06-etapa-6-jenkins.md` — Jenkins (job manual)
- `docs/07-deploy-aplicacoes.md` — deploy eMatricula e novas apps (script + Jenkins)
- `docs/convencoes-e-decisoes.md` — padrões e decisões técnicas
- `docs/versionamento-git.md` — o que versionar e o que não versionar
