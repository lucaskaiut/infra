# Infraestrutura Docker (VPS Ubuntu)

Repositório de infraestrutura: proxy de borda, redes compartilhadas e stacks por aplicação, preparado para CI/CD (Jenkins + GitHub) nas etapas seguintes.

## Mapa do repositório

| Caminho | Função |
|---------|--------|
| `stacks/edge/` | Borda: Traefik, TLS, roteamento por hostname |
| `stacks/apps/*/` | Uma pasta por aplicação (compose próprio, rede `infra_edge` externa) |
| `docs/` | Passos por etapa, convenções e versionamento |

## Ordem das etapas

1. **Etapa 1 — Fundação** (`docs/01-etapa-1-fundacao.md`): Traefik + app demo no navegador (HTTPS).
2. *Próximas:* rede e políticas de deploy, **ematricula** (API do monorepo), zero downtime, Jenkins e webhooks.

Comece pela Etapa 1 e só avance após validar o checklist do final do documento.

## Variáveis de ambiente

Copie `.env.example` para `.env` na raiz do repositório. Em cada pasta de stack, use `docker compose --env-file …` em **todos** os subcomandos que leem o Compose (`up`, `ps`, `down`, …), ou um link simbólico `.env` → raiz, conforme `docs/01-etapa-1-fundacao.md`.

## Documentação

- `docs/01-etapa-1-fundacao.md` — implementação e validação da Etapa 1
- `docs/convencoes-e-decisoes.md` — padrões e decisões técnicas
- `docs/versionamento-git.md` — o que versionar e o que não versionar
