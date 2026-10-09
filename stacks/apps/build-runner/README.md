# Local Build Platform (API + scheduler)

Stack Swarm `infra-app-build-runner` que publica a API da plataforma em
`https://runner.noxtecnologias.com.br` (Traefik + Let's Encrypt).

- Imagem: `local/build-runner-api:latest` (build local a partir do clone
  `android-build-runner/`, gitignored).
- Serviços: `app` (2 réplicas, web/API) e `scheduler` (`builds:reap` a cada
  minuto). O runner Windows consome a API por polling, nunca o contrário.
- Volumes: `build_runner_storage` persistindo `storage/` (artefatos e logs do
  Laravel).
- Deploy: `./ci/deploy-app.sh build-runner` (Jenkins
  `deploy-build-runner-webhook` em push da branch `main`).
- Banco: `build_runner` no MySQL shared (`DB_HOST=mysql`), rede `infra_shared`.
- Segredos de build são gerenciados pelo painel e criptografados com `APP_KEY`
  (não versionar chaves; o `.env` fica só no servidor).

O painel (frontend React) é publicado na Vercel; o `web/vercel.json` do repo da
aplicação faz proxy de `/api` e `/sanctum` para esta API.
