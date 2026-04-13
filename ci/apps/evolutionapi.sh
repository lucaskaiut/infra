APP_COMPOSE_DIR="stacks/apps/evolutionapi"
: "${APP_USE_SWARM:=1}"
: "${APP_SWARM_STACK_NAME:=infra-app-evolutionapi}"
: "${APP_SWARM_COMPOSE_FILE:=docker-stack.yml}"
APP_COMPOSE_PULL_ONLY=1
if [[ "$APP_USE_SWARM" == "0" ]]; then
  : "${APP_COMPOSE_SCALES:=evolutionapi=1}"
fi
