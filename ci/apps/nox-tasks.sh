APP_COMPOSE_DIR="stacks/apps/nox-tasks"
APP_GIT_SUBDIR="nox-tasks"
APP_GIT_REMOTE="https://github.com/lucaskaiut/nox-tasks.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
APP_GIT_USE_SSH=0
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-nox-tasks}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=1}"
fi
APP_HTTP_PROBE_SERVICE_HOST="tasks-api"
APP_HTTP_PROBE_PATH="/up"
APP_DEPLOY_SUBPATH_GUARD="api"
APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_IMAGE="local/nox-tasks-api:latest"
APP_SWARM_FORCE_SERVICE_ROLES="app worker scheduler"
