# Convenções e decisões

## Nomenclatura

- Rede Docker compartilhada: `infra_edge` (nome fixo, declarada na stack `edge`, referenciada como `external` nas apps).
- Projetos Compose: `name` explícito — `infra-edge` (borda) e `infra-app-<slug>` (cada aplicação).
- Containers: prefixo `infra_` + papel (`infra_traefik`, `infra_demo_whoami`, etc.) para identificação rápida em `docker ps`.

## Separação de responsabilidades

- **Este repositório (infra):** proxy, TLS, roteamento, redes, políticas comuns, automação de deploy (Jenkins nas etapas seguintes).
- **Repositório da aplicação (ex.: monorepo ematricula):** código, `Dockerfile` da API, testes. O pipeline publica imagem ou artefato; a infra referencia tag/imagem estável.

## Ferramentas adotadas

| Área | Escolha | Motivo |
|------|---------|--------|
| Proxy / TLS | Traefik v3.6+ (imagem `traefik:v3.6`) | Labels Docker, TLS ACME; **v3.6+** evita falha com Docker Engine 29+ (*client API 1.24 too old*). |
| Orquestração inicial | Docker Compose em stacks separadas | Simples na VPS única, alinhado a “uma pasta por app”, preparado para evoluir |
| Desafio ACME | `tlsChallenge` | Evita conflito típico entre redirecionamento HTTP→HTTPS e HTTP-01 na porta 80 |

## Hostnames (padrão)

- `demo.<DOMAIN>` — serviço de verificação da Etapa 1.
- `traefik.<DOMAIN>` — dashboard API do Traefik (restrinja acesso por firewall ou autenticação nas próximas etapas).

## Segurança (Etapa 1)

- Socket Docker montado somente no Traefik, somente leitura.
- `no-new-privileges` e `read_only` no container Traefik, com `tmpfs` para `/tmp`.
- `exposedByDefault: false` no provedor Docker: só entra no proxy quem tiver `traefik.enable=true`.

## Evolução prevista (sem implementar agora)

- Basic auth ou IP allowlist no dashboard.
- Deploy com rolling update (nova replica + troca de label ou Compose deploy) para zero downtime.
- Jenkins no host ou em container com volume para jobs e credenciais isoladas.
