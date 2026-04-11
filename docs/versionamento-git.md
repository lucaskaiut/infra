# Versionamento em Git

## Versionar (commit)

- Toda a árvore `stacks/` (Compose, Traefik estático/dinâmico, placeholders como `.gitkeep`).
- `docs/` e `README.md`.
- `.env.example` (apenas valores fictícios ou de exemplo).
- `.gitignore`.

## Não versionar

- `stacks/edge/secrets/dashboard.htpasswd` (credenciais do dashboard Traefik). Versiona-se apenas `dashboard.htpasswd.example`.
- `stacks/shared/.env` (credenciais `MYSQL_*` e root).
- `.env` com domínio real, e-mail ACME e segredos.
- Arquivos de certificado ou estado do Let's Encrypt gerados em volume ou bind mount local (ex.: `acme.json` em disco, se no futuro for bind mount).
- Chaves SSH, tokens Jenkins, credenciais de registry.

## Boas práticas

- Alterações de infraestrutura em branches e merge com revisão.
- Para segredos em produção, preferir armazenamento dedicado (Vault, sops, secrets do host) nas etapas avançadas; até lá, `.env` no servidor com permissões restritas (`chmod 600`) e fora do Git.
