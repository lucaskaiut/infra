APP_COMPOSE_DIR="stacks/apps/monensure"
APP_GIT_SUBDIR="monensure"
APP_GIT_REMOTE="https://github.com/lucaskaiut/monensure.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
APP_GIT_USE_SSH=0
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-monensure}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=1}"
fi
APP_HTTP_PROBE_SERVICE_HOST="monensure-api"
APP_HTTP_PROBE_PATH="/up"
APP_DEPLOY_SUBPATH_GUARD="api"
APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_IMAGE="local/monensure-api:latest"
APP_SWARM_FORCE_SERVICE_ROLES="app worker"
