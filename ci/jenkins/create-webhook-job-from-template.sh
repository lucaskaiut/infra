#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_JOB="${1:?uso: $0 <job-template> <novo-job> <caminho-jenkinsfile-no-repo-infra> <webhook-credential-id> [display-slug]}"
NEW_JOB="${2:?}"
JENKINSFILE="${3:?}"
WEBHOOK_CRED="${4:?}"
DISPLAY_SLUG="${5:-}"
if [[ -z "${DISPLAY_SLUG}" ]]; then
  x="${NEW_JOB#deploy-}"
  DISPLAY_SLUG="${x%-webhook}"
fi

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

docker exec \
  -e JFILE="$JENKINSFILE" \
  -e WEBHOOK_CRED="$WEBHOOK_CRED" \
  -e DISPLAY_SLUG="$DISPLAY_SLUG" \
  -e BASE="$BASE" \
  -e SOURCE_JOB="$SOURCE_JOB" \
  -e NEW_JOB="$NEW_JOB" \
  infra_jenkins sh -c '
  set -euo pipefail
  PW=$(grep "^JENKINS_ADMIN_PASSWORD=" /infra-deploy/stacks/jenkins/.env | sed "s/^JENKINS_ADMIN_PASSWORD=//" | tr -d "\r" | sed "s/^\"//;s/\"$//")
  curl -fsSL -o /tmp/jenkins-cli.jar "${BASE}/jnlpJars/jenkins-cli.jar"
  if ! java -jar /tmp/jenkins-cli.jar -s "${BASE}/" -auth admin:${PW} list-jobs | grep -qx "${NEW_JOB}"; then
    java -jar /tmp/jenkins-cli.jar -s "${BASE}/" -auth admin:${PW} copy-job "${SOURCE_JOB}" "${NEW_JOB}"
  fi
  java -jar /tmp/jenkins-cli.jar -s "${BASE}/" -auth admin:${PW} get-job "${NEW_JOB}" \
    | sed "s|<scriptPath>.*</scriptPath>|<scriptPath>${JFILE}</scriptPath>|" \
    | sed "s|<tokenCredentialId>[^<]*</tokenCredentialId>|<tokenCredentialId>${WEBHOOK_CRED}</tokenCredentialId>|g" \
    | sed "s|<causeString>Webhook GitHub [^<]*</causeString>|<causeString>Webhook GitHub ${DISPLAY_SLUG} (ref=\$GIT_REF)</causeString>|" \
    | java -jar /tmp/jenkins-cli.jar -s "${BASE}/" -auth admin:${PW} update-job "${NEW_JOB}"
'

echo "Job ${NEW_JOB} pronto (Jenkinsfile: ${JENKINSFILE}, credencial webhook: ${WEBHOOK_CRED}). Confirma que a credencial Secret text com esse ID existe e coincide com o token na URL do GitHub."
