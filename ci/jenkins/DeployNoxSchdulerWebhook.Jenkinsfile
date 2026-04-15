import groovy.json.JsonSlurper

pipeline {
  agent any
  options {
    disableConcurrentBuilds()
  }
  triggers {
    GenericTrigger(
      causeString: 'Webhook GitHub nox-schduler (ref=$GIT_REF)',
      genericVariables: [
        [key: 'GIT_REF', value: '$.ref', defaultValue: ''],
        [key: 'GIT_BEFORE', value: '$.before', defaultValue: ''],
        [key: 'GIT_AFTER', value: '$.after', defaultValue: ''],
        [key: 'COMMITS_PAYLOAD', value: '$.commits', defaultValue: '[]'],
        [key: 'REPO_FULL', value: '$.repository.full_name', defaultValue: '']
      ],
      tokenCredentialId: 'nox-schduler-webhook-token',
      printContributedVariables: true,
      printPostContent: false
    )
  }
  stages {
    stage('Filtro branch / api / repo') {
      steps {
        script {
          env.RUN_DEPLOY = '0'
          env.DEPLOY_SUBPATH_GIT_RANGE = ''
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
          if (env.REPO_FULL?.trim() && env.REPO_FULL != 'lucaskaiut/nox-schduler') {
            currentBuild.result = 'NOT_BUILT'
            echo "Repositório ignorado: ${env.REPO_FULL}"
            return
          }
          def before = env.GIT_BEFORE?.trim()
          def after = env.GIT_AFTER?.trim()
          if (before && after) {
            def status = sh(
              script: """
                set +e
                cd /infra-deploy
                git pull origin main
                ./ci/check-git-range-touches-path.sh 'https://github.com/lucaskaiut/nox-schduler.git' '${before}' '${after}' api
                exit \$?
              """,
              returnStatus: true
            )
            if (status == 0) {
              env.DEPLOY_SUBPATH_GIT_RANGE = "${before}..${after}"
              env.RUN_DEPLOY = '1'
              return
            }
            if (status == 1) {
              currentBuild.result = 'NOT_BUILT'
              echo 'Sem alterações em api/ neste push (validação por before/after).'
              return
            }
            currentBuild.result = 'NOT_BUILT'
            echo "Não foi possível validar o intervalo Git (código ${status}); deploy não executado."
            return
          }
          def touch = {
            String raw ->
              if (raw == null || raw.trim().isEmpty() || raw.trim() == '[]') {
                return false
              }
              try {
                def slurper = new JsonSlurper()
                def commits = slurper.parseText(raw)
                if (!(commits instanceof List) || commits.isEmpty()) {
                  return false
                }
                for (c in commits) {
                  def paths = []
                  if (c.added instanceof List) {
                    paths.addAll(c.added)
                  }
                  if (c.modified instanceof List) {
                    paths.addAll(c.modified)
                  }
                  if (c.removed instanceof List) {
                    paths.addAll(c.removed)
                  }
                  for (p in paths) {
                    if (p == null) {
                      continue
                    }
                    def s = p.toString()
                    if (s == 'api' || s.startsWith('api/')) {
                      return true
                    }
                  }
                }
                return false
              } catch (Exception e) {
                echo "Payload de commits inválido (${e.message}); sem before/after — deploy não executado."
                return false
              }
          }
          if (!touch.call(env.COMMITS_PAYLOAD)) {
            currentBuild.result = 'NOT_BUILT'
            echo 'Sem alterações relevantes em api/ e sem par before/after no payload; deploy não necessário.'
            return
          }
          env.RUN_DEPLOY = '1'
        }
      }
    }
    stage('Deploy nox-schduler') {
      when {
        environment name: 'RUN_DEPLOY', value: '1'
      }
      steps {
        writeFile file: "${env.WORKSPACE}/.jenkins-notify-commits.json", text: env.COMMITS_PAYLOAD ?: '[]'
        sh """
          set -euo pipefail
          if [ -n "\${JENKINS_URL:-}" ] && ! echo "\$JENKINS_URL" | grep -q '^https://'; then
            echo "ERRO: JENKINS_URL deve começar por https://." >&2
            exit 1
          fi
          cd /infra-deploy
          INFRA_BEFORE=\$(git rev-parse HEAD)
          git pull origin main
          INFRA_AFTER=\$(git rev-parse HEAD)
          echo "\${INFRA_BEFORE}..\${INFRA_AFTER}" > "${env.WORKSPACE}/.jenkins-notify-infra-range.txt"
          export DEPLOY_SUBPATH_GIT_RANGE="\${DEPLOY_SUBPATH_GIT_RANGE:-}"
          export COMMITS_PAYLOAD_FILE="${env.WORKSPACE}/.jenkins-notify-commits.json"
          export NOTIFY_APP_SLUG=nox-schduler
          ./ci/deploy-app.sh nox-schduler
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
            export APP_SLUG=nox-schduler
            export NOTIFY_APP_SLUG=nox-schduler
            export NOTIFY_BUILD_RESULT='${env.NOTIFY_BUILD_RESULT}'
            export COMMITS_PAYLOAD_FILE='${env.WORKSPACE}/.jenkins-notify-commits.json'
            export NOTIFY_GIT_BEFORE='${env.GIT_BEFORE ?: ""}'
            export NOTIFY_GIT_AFTER='${env.GIT_AFTER ?: ""}'
            export NOTIFY_GIT_REF='${env.GIT_REF ?: ""}'
            export NOTIFY_REPO_FULL='${env.REPO_FULL ?: ""}'
            export DEPLOY_SUBPATH_GIT_RANGE='${env.DEPLOY_SUBPATH_GIT_RANGE ?: ""}'
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
