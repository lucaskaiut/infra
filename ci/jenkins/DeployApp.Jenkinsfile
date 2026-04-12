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
          cd /infra-deploy
          git pull origin main
          ./ci/deploy-app.sh ${params.APP_SLUG}
        """
      }
    }
  }
}
