---
name: n8n-workflows
description: Cria ou atualiza workflows n8n via API REST pública (POST/PATCH), JSON de nós e ligações, e variáveis N8N_API_URL e N8N_API_KEY no .env da raiz do repo infra. Usa quando o utilizador pede fluxos n8n, automação via API, import programático, curl para workflows, ou integração com a instância self-hosted documentada em stacks/apps/n8n.
---

# Workflows n8n via API

## Quando aplicar

- Criar, clonar ou atualizar workflows **sem** abrir só a UI.
- Gerar payloads JSON (`nodes`, `connections`) ou `curl` seguros.
- O projeto **infra** expõe `N8N_API_URL` e `N8N_API_KEY` no **`.env` na raiz** (ver `.env.example`); não versionar valores reais.

## Disponibilidade da API (doc oficial)

- Chave em **Settings → n8n API**; em cada pedido enviar o cabeçalho **`X-N8N-API-KEY`** com o valor da chave.
- Em **n8n Cloud**, a API **não** está disponível durante o período de trial gratuito (é preciso plano que inclua API).
- **Self-hosted:** playground OpenAPI em  
  `{N8N_HOST}:{N8N_PORT}{N8N_PATH}/api/v1/docs`  
  (versão da API **`1`**). Útil para validar corpos exatos na tua versão.

Referência: [Authentication](https://docs.n8n.io/api/authentication/), [Public REST API](https://docs.n8n.io/api/), [API playground](https://docs.n8n.io/api/using-api-playground/), [Export/import](https://docs.n8n.io/workflows/export-import/).

## Variáveis neste repositório

- **`N8N_API_URL`**: URL base pública da instância, **sem** barra final, incluindo **`N8N_PATH`** se existir (ex.: `https://n8n.exemplo.com` ou `https://exemplo.com/n8n`).
- **`N8N_API_KEY`**: valor da chave (só no `.env` local; **nunca** em commits nem colado no chat).

Para comandos no terminal, carregar o env sem imprimir segredos:

```bash
set -a && source /caminho/para/infra/.env && set +a
# ou: export $(grep -E '^(N8N_API_URL|N8N_API_KEY)=' .env | xargs)
```

## Endpoints usuais (API v1)

Prefixo: **`${N8N_API_URL}/api/v1`**

| Ação | Método | Caminho |
|------|--------|---------|
| Listar workflows | GET | `/workflows` |
| Criar workflow | POST | `/workflows` |
| Obter um | GET | `/workflows/{id}` |
| Atualizar | PUT ou PATCH | `/workflows/{id}` (confirmar no OpenAPI da instância) |
| Ativar / desativar | PATCH | `/workflows/{id}` com `{ "active": true \| false }` quando suportado |

Parâmetros de listagem (paginação, filtros): ver [Pagination](https://docs.n8n.io/api/pagination/) na doc n8n.

## Corpo ao criar (`POST /workflows`)

A doc pública descreve um corpo com pelo menos:

- **`name`**: string (limite de caracteres na doc / OpenAPI).
- **`nodes`**: array de nós; cada nó costuma incluir `id`, `name`, `type`, `typeVersion`, `position` `[x, y]`, `parameters`.
- **`connections`**: objeto que liga nomes de nós; estrutura típica:

```json
{
  "NomeDoNoOrigem": {
    "main": [[{ "node": "NomeDoNoDestino", "type": "main", "index": 0 }]]
  }
}
```

Se não houver ligações, usar **`"connections": {}`**. Ligações mal formadas podem gerar workflow corrompido na UI (problema conhecido em discussões da API).

Preferir **sempre** o schema do **`/api/v1/docs`** da instância para campos obrigatórios e opcionais na versão instalada.

## A partir de um JSON exportado na UI

1. Exportar o workflow (ficheiro JSON).
2. **Remover ou não enviar** campos específicos da instância que a API recusa ou recria: por exemplo `id`, `versionId`, `active`, timestamps, metadados de execução — alinhar com o exemplo do POST no OpenAPI.
3. **Credenciais:** o export pode referenciar `credentials` por id/nome; nomes podem ser sensíveis. Não partilhar JSON bruto em tickets públicos.
4. **HTTP Request / headers** no export podem conter segredos; anonimizar antes de versionar.

## Limitações a conhecer

- Nós **Code** / função: em alguns casos a API **não persiste** código como na UI; se o fluxo depender disso, validar na instância ou usar nós sem código gerado só via API.
- **Enterprise:** chaves podem ter **scopes** que restringem `workflows:read`, etc.

## Modelo de `curl` (criar)

```bash
curl -sS -X POST "${N8N_API_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @workflow.json
```

**Não** incluir a chave em ficheiros versionados; **não** repetir a chave na resposta ao utilizador.

## Fluxo recomendado para o agente

1. Confirmar objetivo do workflow (gatilho, passos, integrações).
2. Montar `nodes` e `connections` mínimos; nomes de `type` alinhados aos nós n8n (`n8n-nodes-base.*`, etc.).
3. Escrever `workflow.json` temporário ou instruir `curl -d @...`.
4. Sugerir validação no playground **`/api/v1/docs`** ou GET do workflow criado.
5. Se precisar de credenciais OAuth/API, o utilizador cria-as na UI e referencia no JSON conforme o schema exportado de um workflow de teste.

## Alternativa sem API

Import por ficheiro ou URL na UI: [Export and import workflows](https://docs.n8n.io/workflows/export-import/).

## Ligação com a infra deste repo

A stack **n8n** vive em `stacks/apps/n8n/` (Traefik, TLS). `WEBHOOK_URL` e `N8N_HOST` na stack devem coincidir com a URL usada em `N8N_API_URL` para evitar URLs de webhook incorretas.
