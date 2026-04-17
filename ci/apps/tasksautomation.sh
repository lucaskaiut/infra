APP_COMPOSE_DIR="stacks/apps/tasksautomation"
APP_GIT_SUBDIR="tasksautomation"
APP_GIT_REMOTE="https://github.com/lucaskaiut/tasksautomation.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-tasksautomation}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="tasksautomation"

APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_IMAGE="local/tasksautomation-app:latest"
APP_SWARM_FORCE_SERVICE_ROLES="app worker scheduler"
