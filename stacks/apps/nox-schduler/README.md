# Stack nox-schduler (API Laravel)

Publica apenas a pasta `api` do repositório [nox-schduler](https://github.com/lucaskaiut/nox-schduler).

## Pré-requisitos na VPS

- Stack **edge** (Traefik) com rede `infra_edge`.
- Stack **shared** (`stacks/shared/`) com MySQL e Redis na rede `infra_shared`.
- DNS `A` para `api.noxagenda.com.br` apontando para a VPS.
- Acesso de leitura ao repositório `lucaskaiut/nox-schduler` a partir da VPS/Jenkins.

## Primeira vez: clonar o código da API

Na pasta desta stack (`stacks/apps/nox-schduler`):

```bash
git clone https://github.com/lucaskaiut/nox-schduler.git nox-schduler

Se o repositório estiver privado, defina `GITHUB_USERNAME` e `GITHUB_TOKEN` no `.env` da raiz do `infra`; o `./ci/deploy-app.sh nox-schduler` e o webhook do Jenkins passam a usar essa credencial automaticamente.
```

## Variáveis de ambiente

```bash
cp .env.example .env
```

- Gere `APP_KEY` para produção.
- `DB_DATABASE`, `DB_USERNAME` e `DB_PASSWORD` devem apontar para um banco dedicado desta app no MySQL compartilhado.
- `DB_HOST=mysql` e `REDIS_HOST=redis` usam os serviços da stack `shared`.
- `REDIS_PREFIX=nox_scheduler_` evita colisão de chaves com outras apps.

## Deploy

```bash
cd ~/infra && ./ci/deploy-app.sh nox-schduler
```

O deploy faz build da imagem a partir de `nox-schduler/api`, aplica `docker-stack.yml` via Swarm e publica a API em `https://api.noxagenda.com.br`.
