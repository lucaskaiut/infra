APP_COMPOSE_DIR="stacks/apps/horus"
APP_GIT_SUBDIR="horus"
APP_GIT_REMOTE="https://github.com/lucaskaiut/horus.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-horus}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=app=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="horus-api"
APP_DEPLOY_SUBPATH_GUARD="api"
# Mesma tag (:latest): após rebuild o digest local muda mas o stack spec não —
# o Swarm pode manter réplicas na imagem antiga. Força recreação das tarefas da API.
APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_IMAGE="local/horus-api:latest"
APP_SWARM_FORCE_SERVICE_ROLES="${APP_SWARM_FORCE_SERVICE_ROLES:-app worker}"
