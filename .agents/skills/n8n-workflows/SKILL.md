---
name: n8n-workflows
description: Use when the user asks to create, clone, import, or update n8n workflows through the public REST API instead of only using the UI.
---

# n8n Workflows Via API

Use this skill when the user asks to create, clone, import, or update n8n workflows through the public REST API instead of only using the UI.

## What This Skill Covers

- Build or update workflow payloads with `nodes` and `connections`
- Prepare safe `curl` commands for the n8n API
- Work with `N8N_API_URL` and `N8N_API_KEY` from the repo root `.env`
- Guide import/export based workflow migration

## Repository Assumptions

- The infra repository exposes `N8N_API_URL` and `N8N_API_KEY` in the root `.env`
- Real secret values must never be committed or pasted back to the user
- The n8n stack for this repo lives under `stacks/apps/n8n/`

## Environment Variables

- `N8N_API_URL`: public base URL for the instance, without a trailing slash, including `N8N_PATH` if one exists
- `N8N_API_KEY`: API key value stored locally only

When using terminal commands, load the environment without printing secrets.

Example:

```bash
set -a && source /var/www/html/infra/.env && set +a
```

## API Basics

- Authentication uses the `X-N8N-API-KEY` header
- The public API base path is usually `${N8N_API_URL}/api/v1`
- For self-hosted n8n, confirm the exact schema at `${N8N_API_URL}/api/v1/docs` when possible

Common endpoints:

- `GET /workflows`
- `POST /workflows`
- `GET /workflows/{id}`
- `PUT /workflows/{id}` or `PATCH /workflows/{id}` depending on the instance schema
- `POST /workflows/{id}/activate`
- `POST /workflows/{id}/deactivate`

## Recommended Workflow

1. Confirm the workflow goal: trigger, steps, integrations, and expected output.
2. Build the minimum valid `nodes` and `connections`.
3. Prefer matching node types to official n8n names such as `n8n-nodes-base.*`.
4. Keep `connections` as `{}` when there are no links.
5. Create a temporary JSON payload or prepare a `curl -d @workflow.json` command.
6. Suggest validating against `/api/v1/docs` or reading the created workflow back with `GET`.

## Payload Guidance

When creating a workflow, the payload commonly includes:

- `name`
- `nodes`
- `connections`

Nodes typically include:

- `id`
- `name`
- `type`
- `typeVersion`
- `position`
- `parameters`

Connections usually follow this structure:

```json
{
  "Source Node": {
    "main": [[{ "node": "Target Node", "type": "main", "index": 0 }]]
  }
}
```

Malformed connections can create broken workflows in the UI, so keep node names and connection references aligned exactly.

## Importing From Exported JSON

When adapting a workflow exported from the UI:

- Remove instance-specific fields the API may reject, such as `id`, `versionId`, `active`, timestamps, or execution metadata
- Be careful with embedded credential references
- Redact any headers, tokens, or secrets before storing or sharing JSON

## Known Caveats

- Code nodes may not always persist exactly as expected through the API alone
- Enterprise API keys can have scopes that restrict workflow operations
- Instance-specific schema differences should be verified against the local OpenAPI docs

## Safe curl Template

```bash
curl -sS -X POST "${N8N_API_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @workflow.json
```

Do not echo or restate the API key in responses.

## Infra Alignment

- Ensure `WEBHOOK_URL` and `N8N_HOST` in `stacks/apps/n8n/` are consistent with `N8N_API_URL`
- Mismatched public URLs can cause invalid webhook URLs
- If webhook behavior matters, confirm the production URL shown in the n8n node UI for the installed version

## If API Use Is Not Viable

Fallback to UI import/export instead of inventing unsupported API behavior.
