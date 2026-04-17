pipeline {
  agent any
  options {
    disableConcurrentBuilds()
  }
  triggers {
    GenericTrigger(
      causeString: 'Webhook GitHub tasksautomation (ref=$GIT_REF)',
      genericVariables: [
        [key: 'GIT_REF', value: '$.ref', defaultValue: ''],
        [key: 'GIT_BEFORE', value: '$.before', defaultValue: ''],
        [key: 'GIT_AFTER', value: '$.after', defaultValue: ''],
        [key: 'COMMITS_PAYLOAD', value: '$.commits', defaultValue: '[]'],
        [key: 'REPO_FULL', value: '$.repository.full_name', defaultValue: '']
      ],
      tokenCredentialId: 'tasksautomation-webhook-token',
      printContributedVariables: true,
      printPostContent: false
    )
  }
  stages {
    stage('Filtro branch / repo') {
      steps {
        script {
          env.RUN_DEPLOY = '0'
          def causes = currentBuild.getBuildCauses().toString()
          def userTriggered = causes.contains('UserIdCause')
          if (userTriggered) {
            env.RUN_DEPLOY = '1'
            echo 'Disparo manual: a executar deploy completo.'
            return
          }
          if (!env.GIT_REF?.trim()) {
            currentBuild.result = 'NOT_BUILT'
            echo 'Sem ref Git: ignorado (ex.: ping do webhook).'
            return
          }
          if (env.GIT_REF != 'refs/heads/main') {
            currentBuild.result = 'NOT_BUILT'
            echo "Branch ignorada: ${env.GIT_REF}"
            return
          }
          if (env.REPO_FULL?.trim() && env.REPO_FULL != 'lucaskaiut/tasksautomation') {
            currentBuild.result = 'NOT_BUILT'
            echo "Repositório ignorado: ${env.REPO_FULL}"
            return
          }
          env.RUN_DEPLOY = '1'
        }
      }
    }
    stage('Deploy tasksautomation') {
      when {
        environment name: 'RUN_DEPLOY', value: '1'
      }
      steps {
        writeFile file: "${env.WORKSPACE}/.jenkins-notify-commits.json", text: env.COMMITS_PAYLOAD ?: '[]'
        sh """
          set -euo pipefail
          if [ -n "\${JENKINS_URL:-}" ] && ! echo "\$JENKINS_URL" | grep -q '^https://'; then
            echo "ERRO: JENKINS_URL deve começar por https:// (evita aviso 'não seguro' e links HTTP no Jenkins)." >&2
            exit 1
          fi
          cd /infra-deploy
          INFRA_BEFORE=\$(git rev-parse HEAD)
          git pull origin main
          INFRA_AFTER=\$(git rev-parse HEAD)
          echo "\${INFRA_BEFORE}..\${INFRA_AFTER}" > "${env.WORKSPACE}/.jenkins-notify-infra-range.txt"
          export COMMITS_PAYLOAD_FILE="${env.WORKSPACE}/.jenkins-notify-commits.json"
          export NOTIFY_APP_SLUG=tasksautomation
          ./ci/deploy-app.sh tasksautomation
        """
      }
      post {
        always {
          script {
            env.NOTIFY_BUILD_RESULT = currentBuild.currentResult ?: 'FAILURE'
          }
          sh """
            set -eu
            export INFRA_ROOT=/infra-deploy
            export APP_SLUG=tasksautomation
            export NOTIFY_APP_SLUG=tasksautomation
            export NOTIFY_BUILD_RESULT='${env.NOTIFY_BUILD_RESULT}'
            export COMMITS_PAYLOAD_FILE='${env.WORKSPACE}/.jenkins-notify-commits.json'
            export NOTIFY_GIT_BEFORE='${env.GIT_BEFORE ?: ""}'
            export NOTIFY_GIT_AFTER='${env.GIT_AFTER ?: ""}'
            export NOTIFY_GIT_REF='${env.GIT_REF ?: ""}'
            export NOTIFY_REPO_FULL='${env.REPO_FULL ?: ""}'
            RFILE='${env.WORKSPACE}/.jenkins-notify-infra-range.txt'
            if [ -f "\$RFILE" ]; then
              export NOTIFY_INFRA_GIT_RANGE="\$(cat "\$RFILE")"
            fi
            /infra-deploy/ci/notify-n8n-deploy.sh || true
          """
        }
      }
    }
  }
}
