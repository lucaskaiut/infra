pipeline {
  agent any
  parameters {
    string(name: 'APP_SLUG', defaultValue: 'ematricula', description: 'Slug com ficheiro ci/apps/<slug>.sh')
  }
  stages {
    stage('Deploy') {
      steps {
        sh """
          set -euo pipefail
          if [ -n "\${JENKINS_URL:-}" ] && ! echo "\$JENKINS_URL" | grep -q '^https://'; then
            echo "ERRO: JENKINS_URL deve começar por https:// (ver stacks/jenkins/.env.example)." >&2
            exit 1
          fi
          cd /infra-deploy
          git pull origin main
          ./ci/deploy-app.sh ${params.APP_SLUG}
        """
      }
    }
  }
}
