# Guia para agentes (IA) — operação da infra VPS

Documento de entrada para **agentes automatizados** que mantêm o repositório `infra`. Complementa [`arquitetura.md`](arquitetura.md) (detalhe técnico) e [`AGENTS.md`](../AGENTS.md) (regras globais do repo).

**Última auditoria de produção:** 2026-10-13 via `ssh contabo` (somente leitura).

---

## 1. Ambiente de produção

| Item | Valor |
|------|--------|
| Acesso SSH | Host **`contabo`** (configurado no `~/.ssh/config` do operador) |
| Clone na VPS | **`~/infra`** (utilizador `kaiut`) |
| Orquestração | **Docker Swarm** ativo (manager único), Docker Engine **29.x** |
| Proxy / TLS | Stack **`infra-edge`** — Traefik **v3.6** |
| Dados partilhados | Stack **`infra-shared`** — MySQL **8.4**, Redis **7-alpine** |
| CI/CD | **Jenkins** em Compose clássico (`infra_jenkins`), monta `~/infra` em `/infra-deploy` + socket Docker |
| Domínio raiz (`.env` em `~/infra`) | **`lucaskaiut.com.br`** — muitas apps usam **`DOMAIN` próprio** no `.env` da stack |

### 1.1 Comandos de diagnóstico (seguros, read-only)

Executar na VPS após `ssh contabo`:

```bash
cd ~/infra
docker info | grep -i swarm
docker stack ls
docker service ls
docker network ls | grep infra_
docker ps --filter name=jenkins
```

Validação HTTPS (sem credenciais):

```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 https://traefik.lucaskaiut.com.br/dashboard/   # esperado 401
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 https://jenkins.lucaskaiut.com.br/login          # esperado 200
```

### 1.2 Sincronização Git: VPS ↔ GitHub ↔ máquina local

| Checkout | Papel |
|----------|--------|
| **GitHub `origin/main`** | Fonte de verdade versionada |
| **VPS `~/infra`** | Deploy; após `git pull`, alinhado ao remoto (evitar commits só na VPS) |
| **Clone local** | Desenvolvimento; manter `git fetch` / `git pull` antes de editar stacks |

---

## 2. Inventário em produção (stacks Swarm ativas)

| Stack | Hostname(s) públicos (Traefik) | Deploy típico |
|-------|--------------------------------|---------------|
| `infra-edge` | `traefik.lucaskaiut.com.br` | `docker stack deploy` (ver `arquitetura.md` §8) |
| `infra-shared` | — (interno) | idem §9 |
| `infra-app-alura` | `alura-api.lucaskaiut.com.br` | `./ci/deploy-app.sh alura` |
| `infra-app-build-runner` | `runner.noxtecnologias.com.br` | `./ci/deploy-app.sh build-runner` |
| `infra-app-chat-one` | `chatone-api.noxtecnologias.com.br` (+ `/app` Reverb) | `./ci/deploy-app.sh chat-one` |
| `infra-app-evolutionapi` | `evolution.lucaskaiut.com.br` | `./ci/deploy-app.sh evolutionapi` |
| `infra-app-eywa` | `eywa-api.noxtecnologias.com.br` (+ `/app` Reverb) | `./ci/deploy-app.sh eywa` |
| `infra-app-financeiro-apolar` | `financeiro-apolar-api.noxtecnologias.com.br` | `./ci/deploy-app.sh financeiro-apolar` |
| `infra-app-financeiro-borcath` | `financeiro-api.dborcath.com.br` | `./ci/deploy-app.sh financeiro-borcath` |
| `infra-app-hedgedoc` | `docs.lucaskaiut.com.br` | manual (`docker stack deploy`; ver README da stack) |
| `infra-app-minha-rotina` | `minharotina-api.noxtecnologias.com.br` | `./ci/deploy-app.sh minha-rotina` |
| `infra-app-monensure` | `monensure-api.noxtecnologias.com.br` | `./ci/deploy-app.sh monensure` |
| `infra-app-n8n` | `n8n.lucaskaiut.com.br` | `./ci/deploy-app.sh n8n` |
| `infra-app-nox-cms` | `cms-api.noxtecnologias.com.br` | `./ci/deploy-app.sh nox-cms` |
| `infra-app-nox-schduler` | `api.noxagenda.com.br` | `./ci/deploy-app.sh nox-schduler` |
| `infra-app-traccar` | `dispositivos.nuvemax.srv.br`, `traccar.noxtecnologias.com.br` | `./ci/deploy-app.sh traccar` (pode existir só na VPS até versionar no Git) |
| `infra-app-vulcano` | `sistema-api.dborcath.com.br` | `./ci/deploy-app.sh vulcano` |
| `infra-app-webraster` | ver `arquitetura.md` §6.1 | `./ci/deploy-app.sh webraster` |

**Jenkins (Compose):** `https://jenkins.lucaskaiut.com.br` — contentor `infra_jenkins`.

**No repo, sem stack na VPS (2026-10-13):** Uptime Kuma, Netdata, OpenSearch; apps preparadas mas paradas (ematricula, horus, …) — ver `arquitetura.md` §10.3.

---

## 3. Passos para subir um **novo** projeto

Ver [`.agents/skills/new-vps-app-stack/SKILL.md`](../.agents/skills/new-vps-app-stack/SKILL.md) e [`.cursor/rules/novos-projetos-ci-jenkins.mdc`](../.cursor/rules/novos-projetos-ci-jenkins.mdc).

1. `cp -r stacks/apps/_template stacks/apps/<slug>` — ajustar YAML, labels Traefik em **`deploy.labels`**, redes, `.env.example`
2. DNS **A**; `.env` real só na VPS (`chmod 600`)
3. `ci/apps/<slug>.sh` + `./ci/deploy-app.sh <slug>`
4. Validar: `docker compose config` / `docker stack ps` / `curl` HTTPS
5. CI/CD opcional: Jenkinsfile, job na VPS, webhook GitHub (segredo só no Jenkins)

**Proibido** sem autorização explícita: `docker compose down`, paragens destrutivas, expor segredos no Git.

---

## 4. Segredos e GitHub

Não versionar: `.env` com credenciais, `acme.json`, `dashboard.htpasswd`, chaves privadas, `webhook-token.txt`, clones de apps em `stacks/apps/*/<repo>/`.

Antes de commit: `git status`, `git check-ignore` nos `.env`, rever diff sem passwords reais.

---

## 5. Referências

| Tarefa | Documento |
|--------|-----------|
| Detalhe técnico | [`docs/arquitetura.md`](arquitetura.md) |
| Deploy seguro | [`.agents/skills/safe-stack-deploy/SKILL.md`](../.agents/skills/safe-stack-deploy/SKILL.md) |
| Diagnóstico | [`.agents/skills/vps-infra-troubleshooting/SKILL.md`](../.agents/skills/vps-infra-troubleshooting/SKILL.md) |
| Regras de uptime | [`.cursor/rules/vps-uptime-e-seguranca.mdc`](../.cursor/rules/vps-uptime-e-seguranca.mdc) |

Respostas ao utilizador em **português**. Não logar valores de variáveis sensíveis.
