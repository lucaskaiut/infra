# Infra Repo Instructions

This repository is for infrastructure work. Apply these instructions by default when working here.

## Scope

- Focus on infrastructure only: Docker Compose, proxy, TLS, packaging images, example environment variables, and deployment documentation.
- Do not change application source code from upstream projects or app repositories from this repo context.
- If an app fails with 5xx, route, auth, or job errors, report the symptom and relevant logs, then keep troubleshooting on the infra side.

## VPS Uptime And Safety

- Prioritize keeping production services online.
- Avoid disruptive restarts, stops, removals, or downtime unless they are strictly necessary and the user explicitly authorized the impact.
- If there is any doubt about a destructive action, stop and ask first.

Do not perform these actions without explicit user approval:

- `docker compose down`
- `docker stop`, `docker kill`, or `docker rm -f` on production services
- `docker volume rm`, `docker system prune`, or `docker network rm` on in-use resources
- Deleting persistent data such as Let's Encrypt, databases, or uploads
- `git reset --hard`
- `git push --force` on shared branches
- Disabling firewall protections, opening unnecessary ports, or exposing dashboards without hardening context
- Printing, requesting, committing, or pasting secrets such as `.env` contents, API keys, or private keys

## Safe Default Actions

- `git pull` on the VPS infra checkout
- `docker compose pull`
- `docker compose up -d`
- Read-only checks such as `docker compose ps`, `docker logs`, `curl` health checks, and `grep` on versioned config files

Prefer incremental updates and only recreate affected services.

## Validation Before Commit, Push, Or Deploy

Before commit, push, or deploy, validate what changed:

- Check syntax for changed YAML, JSON, and Dockerfiles
- Run `docker compose config` for affected stacks
- If an image build is involved, build locally without starting containers when practical
- Verify required environment variables referenced by Compose

If validation fails:

- Do not commit
- Do not push
- Report the failure clearly

## Least Privilege And Network Isolation

When creating or changing services:

- Do not use `privileged: true` unless truly required
- Avoid running as root when possible
- Limit Linux capabilities when possible
- Expose only the ports that are strictly needed
- Keep databases off the host network surface
- Use separate networks by context instead of putting everything on one shared default network

If an exception is required, explain why.

## Rollback And Verification

After deploy or restart:

- Check `docker compose ps`
- Review logs for critical containers
- Validate health checks or HTTP responses

If health checks fail, HTTP is not `200`, or a container is crash-looping:

- Do not keep forcing the broken state
- Suggest rollback
- Prefer reverting to the last known good version if available

Do not leave services broken without a recovery path.

## Reproducibility And Secrets

- Prefer changes that are reproducible through code, not manual VPS state
- If manual action is unavoidable, document it clearly
- Prefer versioned images instead of `latest`
- Keep critical variables explicit
- Never log secret values
- When showing examples, use placeholders instead of real secret data

## Git And Push Workflow

When the task leaves tracked files changed and the user did not explicitly say not to version them:

1. Review with `git status` and, when useful, `git diff`.
2. Stage explicit paths only.
3. Never stage secrets, `.env`, private keys, or files like `acme.json`.
4. Create a short, clear commit message.
5. Push the current branch with `git push origin`.

Treat this as the default behavior for this repository, including infra docs, `.cursor/rules`, and `.agents/skills`: do not stop after editing files if the changes are valid and safe to version.

If push fails, prefer `git pull --rebase` and retry, or report the issue. Do not force-push unless the user explicitly requested it.

## VPS Sync After Push

If this project has a deployment flow and SSH access is available, a successful push should normally be followed by VPS synchronization:

1. Pull the updated branch on the VPS infra checkout.
2. Reload only the affected stacks.
3. Validate container status, logs, and relevant HTTPS endpoints.

If SSH is unavailable or the user did not ask for deploy, report the push as done and provide the VPS commands the user can run manually.

## n8n Skill

- When the user asks for n8n workflow creation or updates via API, use the local skill at `.agents/skills/n8n-workflows/SKILL.md`.
