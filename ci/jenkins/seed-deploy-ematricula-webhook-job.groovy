import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.UserRemoteConfig
import java.util.Collections
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def j = Jenkins.getInstanceOrNull()
if (j == null) {
  return
}

def jobName = "deploy-ematricula-webhook"
if (j.getItem(jobName) != null) {
  println "Job ${jobName} já existe."
  return
}

def remote = "https://github.com/lucaskaiut/infra.git"
def credId = System.getenv("GITHUB_TOKEN")?.trim() ? "github-readonly" : null
def repos = Collections.singletonList(new UserRemoteConfig(remote, null, null, credId))
def branches = Collections.singletonList(new BranchSpec("*/main"))
def scm = new GitSCM(
  repos,
  branches,
  false,
  Collections.emptyList(),
  null,
  null,
  Collections.emptyList()
)

def job = j.createProject(WorkflowJob.class, jobName)
job.setDefinition(new CpsScmFlowDefinition(scm, "ci/jenkins/DeployEmatriculaWebhook.Jenkinsfile"))
job.save()
println "Job ${jobName} criado. Cria a credencial Secret text com ID ematricula-webhook-token antes do primeiro webhook."
