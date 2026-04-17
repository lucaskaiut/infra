# tasksautomation (Laravel)

Imagem a partir do repositório [tasksautomation](https://github.com/lucaskaiut/tasksautomation): Nginx + PHP-FPM, worker de filas e scheduler. TLS e hostname no Traefik: `tasksautomation.${DOMAIN}` (ex.: `tasksautomation.lucaskaiut.com.br`).

## Pré-requisitos na VPS

- Swarm + redes `infra_edge` e `infra_shared` (`ci/swarm-bootstrap.sh`)
- Stacks `infra-shared` (MySQL, Redis) e `infra-edge` (Traefik)
- DNS `A` para `tasksautomation.<domínio>` → IP da VPS

## MySQL

Criar base e utilizador (ajustar palavras-passe; alinhar com `DB_*` no `.env` da stack):

```sql
CREATE DATABASE IF NOT EXISTS tasksautomation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'tasksautomation'@'%' IDENTIFIED BY 'SENHA_FORTE';
GRANT ALL PRIVILEGES ON tasksautomation.* TO 'tasksautomation'@'%';
FLUSH PRIVILEGES;
```

## Primeira subida

O clone deve incluir `composer.lock` (se faltar, corre `composer update` no projeto e faz commit do ficheiro).

```bash
cd ~/infra/stacks/apps/tasksautomation
git clone https://github.com/lucaskaiut/tasksautomation.git tasksautomation
cp .env.example .env
```

Editar `.env`: `APP_KEY` (ex.: `php artisan key:generate --show`), `DB_*`, `APP_URL` coerente com o hostname público.

Deploy:

```bash
cd ~/infra && ./ci/deploy-app.sh tasksautomation
```

## CI/CD

- **Jenkins:** job `deploy-tasksautomation-webhook` (ver `ci/jenkins/DeployTasksautomationWebhook.Jenkinsfile` e `seed-deploy-tasksautomation-webhook-job.groovy`); webhook GitHub no repositório da aplicação com token `tasksautomation-webhook-token`.
- **GitHub Actions (repo infra):** workflow `.github/workflows/tasksautomation-stack.yml` valida `docker compose config` quando alteras esta stack.
- **GitHub Actions (repo da app):** modelo em `ci/tasksautomation-app-github-ci.yml.example` na raiz do repositório **infra** — copiar para `.github/workflows/ci.yml` no repositório `tasksautomation` e ajustar passos (PHP, testes) ao que o projeto usar.

## Compose sem Swarm

Em `ci/apps/tasksautomation.sh`, definir `APP_USE_SWARM=0` (ou export antes do deploy) para usar só `docker compose` com réplicas locais conforme `APP_COMPOSE_SCALES`.
