pipeline {
  agent any
  parameters {
    string(name: 'APP_SLUG', defaultValue: 'ematricula', description: 'Slug com ficheiro ci/apps/<slug>.sh')
  }
  stages {
    stage('Deploy na VPS') {
      steps {
        sshagent(credentials: ['vps-deploy-ssh']) {
          sh """
            set -euo pipefail
            test -n "${env.DEPLOY_SSH_USER}" && test -n "${env.DEPLOY_SSH_HOST}"
            ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ${env.DEPLOY_SSH_USER}@${env.DEPLOY_SSH_HOST} \\
              "cd ~/infra && git pull origin main && ./ci/deploy-app.sh ${params.APP_SLUG}"
          """
        }
      }
    }
  }
}
