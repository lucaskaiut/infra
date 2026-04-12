APP_COMPOSE_DIR="stacks/apps/ematricula"
APP_GIT_SUBDIR="ematricula"
APP_GIT_REMOTE="https://github.com/lucaskaiut/ematricula.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-ematricula}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="ematricula-api"
