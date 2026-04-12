import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def j = Jenkins.getInstanceOrNull()
if (j == null) {
  return
}

def jobName = "ci-smoke"
if (j.getItem(jobName) != null) {
  return
}

def repo = System.getenv("GITHUB_REPO_URL")?.trim() ?: "https://github.com/lucaskaiut/infra.git"
def hasToken = System.getenv("GITHUB_TOKEN")?.trim()

def gitStep = hasToken
  ? "git branch: 'main', credentialsId: 'github-readonly', url: '${repo}'"
  : "git branch: 'main', url: '${repo}'"

def pipelineScript = """
pipeline {
  agent any
  options {
    timestamps()
  }
  stages {
    stage('Checkout') {
      steps {
        ${gitStep}
      }
    }
    stage('Echo') {
      steps {
        echo 'CI smoke OK — sem deploy na VPS'
      }
    }
  }
}
""".stripIndent()

def job = j.createProject(WorkflowJob.class, jobName)
job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
job.save()
