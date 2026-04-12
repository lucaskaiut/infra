import groovy.json.JsonSlurper

pipeline {
  agent any
  options {
    disableConcurrentBuilds()
  }
  triggers {
    GenericTrigger(
      causeString: 'Webhook GitHub ematricula (ref=$GIT_REF)',
      genericVariables: [
        [key: 'GIT_REF', value: '$.ref', defaultValue: ''],
        [key: 'COMMITS_PAYLOAD', value: '$.commits', defaultValue: '[]'],
        [key: 'REPO_FULL', value: '$.repository.full_name', defaultValue: '']
      ],
      tokenCredentialId: 'ematricula-webhook-token',
      printContributedVariables: true,
      printPostContent: false
    )
  }
  stages {
    stage('Filtro branch / api / repo') {
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
          if (env.REPO_FULL?.trim() && env.REPO_FULL != 'lucaskaiut/ematricula') {
            currentBuild.result = 'NOT_BUILT'
            echo "Repositório ignorado: ${env.REPO_FULL}"
            return
          }
          def touch = {
            String raw ->
              if (raw == null || raw.trim().isEmpty() || raw.trim() == '[]') {
                return true
              }
              try {
                def slurper = new JsonSlurper()
                def commits = slurper.parseText(raw)
                if (!(commits instanceof List) || commits.isEmpty()) {
                  return true
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
                echo "Aviso: não foi possível analisar commits (${e.message}); a executar deploy por segurança."
                return true
              }
          }
          if (!touch.call(env.COMMITS_PAYLOAD)) {
            currentBuild.result = 'NOT_BUILT'
            echo 'Sem alterações relevantes em api/: deploy não necessário.'
            return
          }
          env.RUN_DEPLOY = '1'
        }
      }
    }
    stage('Deploy eMatricula') {
      when {
        environment name: 'RUN_DEPLOY', value: '1'
      }
      steps {
        sh """
          set -euo pipefail
          cd /infra-deploy
          git pull origin main
          ./ci/deploy-app.sh ematricula
        """
      }
    }
  }
}
