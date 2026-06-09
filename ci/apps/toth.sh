APP_COMPOSE_DIR="stacks/apps/toth"
APP_GIT_SUBDIR="toth"
APP_GIT_REMOTE="https://github.com/lucaskaiut/toth.git"
APP_GIT_BRANCH="${APP_GIT_BRANCH:-main}"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-toth}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=nginx=2}"
fi
APP_HTTP_PROBE_SERVICE_HOST="toth-api"
APP_HTTP_PROBE_PATH="/up"
APP_DEPLOY_SUBPATH_GUARD="api"
APP_SWARM_FORCE_SERVICE_UPDATE=1
APP_SWARM_FORCE_SERVICE_ROLES="${APP_SWARM_FORCE_SERVICE_ROLES:-nginx api worker reverb}"
# Duas imagens locais (:latest); força recreação após rebuild.
APP_SWARM_FORCE_IMAGES=$'nginx local/toth-nginx:latest\napi local/toth-php:latest\nworker local/toth-php:latest\nreverb local/toth-php:latest'
