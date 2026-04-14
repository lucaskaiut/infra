---
name: new-vps-app-stack
description: Use when the user asks to add a new application stack to this VPS infra repo. Create a stack from the template, wire Traefik routing, attach only needed networks, define example env vars, and keep application code outside this repo.
---

# New VPS App Stack

Use this skill to scaffold a new app stack in this repo.

## Default Pattern

1. Start from `stacks/apps/_template/`
2. Rename service, image, hostnames, and labels for the new slug
3. Attach to:
   - `infra_edge` if the app is exposed publicly
   - `infra_shared` only if it needs MySQL or Redis
4. Add only the required ports, volumes, and env examples
5. Keep deployment instructions aligned with `ci/deploy-app.sh` when applicable

## Required Checks

- Traefik host rule matches the intended public domain
- Service is not exposed directly on the host unless necessary
- Database and cache are private on shared networks
- Image tags are explicit
- Secrets stay out of versioned files

## Do Not Do

- Do not vendor application source code into this repo
- Do not patch upstream app files here
- Do not put every service on every network
- Do not expose internal admin ports by default

## Typical Deliverables

- `stacks/apps/<slug>/docker-compose.yml`
- `stacks/apps/<slug>/docker-stack.yml` when production uses Swarm
- `.env.example`
- short README or doc update only if needed for operation

## Cross-Checks

- If the app needs webhooks, align public URL variables with Traefik
- If the app needs workers or schedulers, keep them internal unless they need public routing
- If the app uses shared MySQL or Redis, document the expected env variable names with placeholders only

