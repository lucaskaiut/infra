# Etapa 2 — Proteger o dashboard Traefik

## Objetivo

O dashboard em `https://traefik.<DOMAIN>` deixa de ser acessível sem credenciais, usando **HTTP Basic Auth** e ficheiro `htpasswd` fora do Git.

## Ficheiros

| Caminho | Função |
|---------|--------|
| `stacks/edge/traefik/dynamic/dashboard-auth.yml` | Middleware `traefik-dashboard-auth` com `usersFile` |
| `stacks/edge/secrets/dashboard.htpasswd.example` | Exemplo versionado (utilizador `admin` e senha inicial documentada abaixo) |
| `stacks/edge/secrets/dashboard.htpasswd` | Ficheiro real na VPS — **não** versionado (`.gitignore`) |

## Primeira configuração na VPS

Na primeira vez (ou após clone):

```bash
cd ~/infra/stacks/edge/secrets
cp -n dashboard.htpasswd.example dashboard.htpasswd
```

Troque a senha o quanto antes (em Debian/Ubuntu: `sudo apt install apache2-utils` se não existir `htpasswd`):

```bash
htpasswd -cB dashboard.htpasswd admin
```

Isto substitui o ficheiro. Reinicie o Traefik:

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
```

## Senha de exemplo (apenas bootstrap)

O ficheiro `dashboard.htpasswd.example` corresponde à senha **`TroqueEstaSenha!`** para o utilizador **`admin`**. Não use em produção sem alterar.

## Validação

- Sem credenciais: `curl -sS -o /dev/null -w '%{http_code}' https://traefik.<DOMAIN>/dashboard/` → **401**.
- Com credenciais corretas: mesmo URL com `-u admin:...` → **200** (ou redirecionamento aceitável para o dashboard).

As outras rotas (ex.: `demo.<DOMAIN>`) **não** usam este middleware e continuam como antes.

## Alternativa avançada

Restringir por IP na firewall (UFW) ou VPN é complementar; o Basic Auth já evita exposição anónima na web.
