# Infraestrutura Docker (VPS Ubuntu)

Repositório de infraestrutura: proxy de borda, redes compartilhadas e stacks por aplicação, preparado para CI/CD (Jenkins + GitHub) nas etapas seguintes.

## Mapa do repositório

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Borda: Traefik, TLS, roteamento por hostname |
| `stacks/apps/*/` | Uma pasta por aplicação (compose próprio, rede `infra_edge` externa) |
| `stacks/apps/_template/` | Modelo para copiar ao criar uma nova app |
| `docs/` | Passos por etapa, convenções e versionamento |

## Ordem das etapas

1. **Etapa 1 — Fundação** (`docs/01-etapa-1-fundacao.md`): Traefik + app demo (HTTPS).
2. **Etapa 2 — Dashboard** (`docs/02-etapa-2-dashboard-auth.md`): Basic Auth no dashboard Traefik.
3. **Etapa 3 — Template** (`docs/03-etapa-3-template-nova-app.md`): modelo `stacks/apps/_template/` para novas apps.
4. *Próximas:* **ematricula** (API), serviços partilhados, zero downtime, Jenkins e webhooks GitHub.

Avance etapa a etapa e valide cada documento antes de seguir.

## Variáveis de ambiente

Copie `.env.example` para `.env` na raiz do repositório. Em cada pasta de stack, use `docker compose --env-file …` em **todos** os subcomandos que leem o Compose (`up`, `ps`, `down`, …), ou um link simbólico `.env` → raiz, conforme `docs/01-etapa-1-fundacao.md`.

## Documentação

- `docs/01-etapa-1-fundacao.md` — Etapa 1
- `docs/02-etapa-2-dashboard-auth.md` — Etapa 2
- `docs/03-etapa-3-template-nova-app.md` — Etapa 3
- `docs/convencoes-e-decisoes.md` — padrões e decisões técnicas
- `docs/versionamento-git.md` — o que versionar e o que não versionar
