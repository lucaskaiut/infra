---
name: safe-stack-deploy
description: Use when the user asks to deploy or update infrastructure on the VPS for this repo. Apply incremental Docker Compose or Swarm updates, validate configs before deploy, avoid downtime, and verify logs and HTTP health after changes.
---

# Safe Stack Deploy

Use this skill when changing or deploying infra in this repository.

## Principles

- Prefer incremental reloads over disruptive restarts
- Reload only affected stacks
- Validate before commit, push, or deploy
- Never expose secrets in output

## Workflow

1. Identify the affected stack:
   - `stacks/edge/`
   - `stacks/shared/`
   - `stacks/apps/<slug>/`
   - `stacks/jenkins/`
2. Validate changed files:
   - YAML and JSON syntax
   - `docker compose config` for the affected stack
   - required env variable names referenced by the Compose file
3. If an image changes, build or pull only what is needed.
4. Prefer:
   - `docker compose pull`
   - `docker compose up -d`
   - `docker stack deploy`
5. After deploy, always verify:
   - status
   - logs
   - public HTTP or HTTPS response

## Swarm Notes

- Keep Swarm labels under `deploy.labels`
- When rendering a stack file from Compose, preserve env interpolation
- If only mounted Traefik config changed, a force update may be needed for the Traefik service

## Validation Checklist

- `docker compose config` succeeds
- expected external networks exist
- expected volumes are unchanged unless the user explicitly approved data-impacting changes
- no accidental `latest` tag introduced for critical services

## Safety Boundaries

- Do not run `docker compose down` without explicit approval
- Do not remove volumes, networks, or persistent data without explicit approval
- If health checks fail after deploy, stop and propose rollback instead of forcing more changes

