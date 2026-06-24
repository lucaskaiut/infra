APP_COMPOSE_DIR="stacks/apps/vulcano"
APP_GIT_SUBDIR="vulcano"
APP_GIT_REMOTE="git@github.com:lucaskaiut/vulcano.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
APP_GIT_USE_SSH=1
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-vulcano}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="vulcano-api"
APP_DEPLOY_SUBPATH_GUARD="api"
APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_IMAGE="local/vulcano-api:latest"
APP_SWARM_FORCE_SERVICE_ROLES="${APP_SWARM_FORCE_SERVICE_ROLES:-app worker scheduler}"
