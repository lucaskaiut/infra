APP_COMPOSE_DIR="stacks/apps/nox-schduler"
APP_GIT_SUBDIR="nox-schduler"
APP_GIT_REMOTE="${APP_GIT_REMOTE:-https://github.com/lucaskaiut/nox-schduler.git}"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-nox-schduler}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="api"
APP_DEPLOY_SUBPATH_GUARD="api"
