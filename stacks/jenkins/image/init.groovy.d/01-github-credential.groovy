import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl

def token = System.getenv("GITHUB_TOKEN")?.trim()
if (!token) {
  return
}

def username = System.getenv("GITHUB_USERNAME")?.trim() ?: "git"
def store = SystemCredentialsProvider.getInstance().getStore()
def existing = store.getCredentials(Domain.global()).find { it.id == "github-readonly" }
if (existing != null) {
  return
}

def cred = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  "github-readonly",
  "GitHub read-only (PAT) para checkout",
  username,
  token
)
store.addCredentials(Domain.global(), cred)
