# Infraestrutura Docker (VPS Ubuntu)

Repositório de infraestrutura: Traefik (TLS e roteamento), MySQL e Redis partilhados, stacks Compose por aplicação, Jenkins e automação em `ci/`.

## Documentação

**[docs/arquitetura.md](docs/arquitetura.md)** — documento único: arquitetura, decisões, ordem de arranque na VPS, Traefik, shared, apps (incl. eMatricula), Jenkins, webhooks, deploy, versionamento e diagnóstico.

## Mapa do repositório

| Caminho | Função |
|---------|--------|
| `docs/arquitetura.md` | Toda a documentação operacional |
| `stacks/edge/` | Traefik, rede `infra_edge` |
| `stacks/shared/` | MySQL + Redis, rede `infra_shared` |
| `stacks/apps/*/` | Uma pasta por aplicação |
| `stacks/apps/_template/` | Modelo para nova app |
| `stacks/jenkins/` | Jenkins (CI/CD) |
| `ci/` | `deploy-app.sh`, `ci/apps/*.sh`, Jenkinsfiles |

## Variáveis de ambiente

Copia `.env.example` para `.env` na raiz onde aplicável. Em cada stack, usa `docker compose --env-file …` em **todos** os subcomandos que leem o Compose, ou um link simbólico `.env` na pasta do projeto, conforme descrito em `docs/arquitetura.md` (secção sobre interpolação e ficheiros `.env`).
