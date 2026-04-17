#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_JOB="${1:?uso: $0 <job-template> <novo-job> <caminho-jenkinsfile-no-repo-infra>}"
NEW_JOB="${2:?}"
JENKINSFILE="${3:?}"

JENKINS_ENV="${ROOT}/stacks/jenkins/.env"
if [[ ! -f "$JENKINS_ENV" ]]; then
  echo "Falta ${JENKINS_ENV}" >&2
  exit 1
fi

BASE="$(grep -E '^JENKINS_URL=' "$JENKINS_ENV" | cut -d= -f2- | tr -d '\r' | sed 's/^"//;s/"$//')"
BASE="${BASE%/}"
if [[ -z "$BASE" ]]; then
  echo "JENKINS_URL em falta em ${JENKINS_ENV}" >&2
  exit 1
fi

docker exec -e JFILE="$JENKINSFILE" infra_jenkins sh -c "
  set -euo pipefail
  PW=\$(grep '^JENKINS_ADMIN_PASSWORD=' /infra-deploy/stacks/jenkins/.env | sed 's/^JENKINS_ADMIN_PASSWORD=//' | tr -d '\r' | sed 's/^\"//;s/\"\$//')
  curl -fsSL -o /tmp/jenkins-cli.jar \"${BASE}/jnlpJars/jenkins-cli.jar\"
  if ! java -jar /tmp/jenkins-cli.jar -s ${BASE}/ -auth admin:\${PW} list-jobs | grep -qx '${NEW_JOB}'; then
    java -jar /tmp/jenkins-cli.jar -s ${BASE}/ -auth admin:\${PW} copy-job '${SOURCE_JOB}' '${NEW_JOB}'
  fi
  java -jar /tmp/jenkins-cli.jar -s ${BASE}/ -auth admin:\${PW} get-job '${NEW_JOB}' \
    | sed \"s|<scriptPath>.*</scriptPath>|<scriptPath>\${JFILE}</scriptPath>|\" \
    | java -jar /tmp/jenkins-cli.jar -s ${BASE}/ -auth admin:\${PW} update-job '${NEW_JOB}'
"

echo "Job ${NEW_JOB} pronto (Jenkinsfile: ${JENKINSFILE}). Cria a credencial Secret text do webhook se ainda não existir."
