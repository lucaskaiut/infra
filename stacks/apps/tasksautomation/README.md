# tasksautomation (Laravel)

Imagem a partir do repositório [tasksautomation](https://github.com/lucaskaiut/tasksautomation): Nginx + PHP-FPM, worker de filas, scheduler e websocket dedicado. TLS e hostname no Traefik: `tasksautomation.${DOMAIN}` (ex.: `tasksautomation.lucaskaiut.com.br`).

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

Editar `.env`: `APP_KEY` (ex.: `php artisan key:generate --show`), `DB_*`, `APP_URL` coerente com o hostname público e variáveis de realtime:

- `TASKS_REALTIME_BRIDGE_HOST=websocket`
- `TASKS_REALTIME_BRIDGE_PORT=8082`
- `TASKS_REALTIME_WS_PATH=/ws/tasks`
- `TASKS_REALTIME_TOKEN_TTL_SECONDS=28800`

Deploy:

```bash
cd ~/infra && ./ci/deploy-app.sh tasksautomation
```

O script faz `git pull` no clone da app **e** `docker compose build`; a imagem inclui o ficheiro **`.app-git-commit`** (commit Git da app no momento do build). O build também gera os assets frontend com `npm run build` dentro da imagem, então mudanças de JS/Blade ligadas ao realtime seguem no mesmo artefato do deploy.

Com **Swarm** e imagem **`local/tasksautomation-app:latest`**, o `docker stack deploy` pode não recriar tarefas quando só muda a digest local — `ci/apps/tasksautomation.sh` ativa `APP_SWARM_FORCE_SERVICE_UPDATE` para correr `docker service update --force` nos serviços `app`, `worker`, `scheduler` e `websocket` após o deploy. Isto é obrigatório para o websocket, porque ele é processo longo e não recarrega código sozinho.

O Nginx da imagem faz proxy de `/ws/tasks` para o serviço interno `websocket:8081`, mantendo o PHP-FPM isolado no processo web normal. O Laravel publica eventos no **bridge TCP** (`TASKS_REALTIME_BRIDGE_HOST` / porta 8082): é outro canal do browser→WSS. O `docker-compose.yml` e o `docker-stack.yml` fixam essas variáveis nos serviços `app`, `worker`, `scheduler` e `websocket` para não depender de um `.env` incompleto ou copiado do repo da app com `127.0.0.1`.

Se a lista inicial sincroniza mas as alterações em tempo real não aparecem: confirma que o serviço `websocket` está em execução e que, a partir de um contentor `app`, `gethostbyname('websocket')` e ligação TCP à porta 8082 funcionam (o publisher falha em silêncio se o bridge não for alcançável).

Se o código em GitHub estiver à frente dos contentores, o clone em `tasksautomation/` pode já estar atualizado, mas a imagem em execução **não** — falta correr o deploy (ou o webhook Jenkins) para **reconstruir** a imagem. Para confirmar: `docker exec <container> cat /var/www/html/.app-git-commit` e comparar com `git -C stacks/apps/tasksautomation/tasksautomation rev-parse HEAD` na VPS.

## CI/CD

- **Jenkins:** job `deploy-tasksautomation-webhook` (ver `ci/jenkins/DeployTasksautomationWebhook.Jenkinsfile` e `seed-deploy-tasksautomation-webhook-job.groovy`). Criação/atualização na VPS: `./ci/jenkins/create-webhook-job-from-template.sh deploy-ematricula-webhook deploy-tasksautomation-webhook ci/jenkins/DeployTasksautomationWebhook.Jenkinsfile tasksautomation-webhook-token` (ajusta `tokenCredentialId` persistido, não só o Jenkinsfile). Webhook GitHub: credencial Secret text `tasksautomation-webhook-token` = mesmo valor do parâmetro `token=` na URL.
- **GitHub Actions (repo infra):** workflow `.github/workflows/tasksautomation-stack.yml` valida `docker compose config` quando alteras esta stack.
- **GitHub Actions (repo da app):** modelo em `ci/tasksautomation-app-github-ci.yml.example` na raiz do repositório **infra** — copiar para `.github/workflows/ci.yml` no repositório `tasksautomation` e ajustar passos (PHP, testes) ao que o projeto usar.

## Compose sem Swarm

Em `ci/apps/tasksautomation.sh`, definir `APP_USE_SWARM=0` (ou export antes do deploy) para usar só `docker compose` com réplicas locais conforme `APP_COMPOSE_SCALES`.

Nesse modo, quando houver mudança de realtime, recriar explicitamente os contentores afetados:

```bash
docker compose up -d --force-recreate app websocket
```

Validação recomendada após deploy:

- `docker service ls | grep tasksautomation` ou `docker compose ps`
- `docker service logs infra-app-tasksautomation_websocket --tail 100` ou `docker compose logs websocket --tail 100`
- `curl -I https://tasksautomation.<domínio>/ws/tasks`
- testar criação, claim, update e delete na interface
