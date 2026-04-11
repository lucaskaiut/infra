# Etapa 1 — Fundação: Traefik + demo no navegador (HTTPS)

Objetivo: ter um serviço HTTP interno publicado com TLS válido, atrás do Traefik, com estrutura de pastas reutilizável para novas aplicações.

**Premissas:** VPS Ubuntu, Docker e Docker Compose plugin instalados, domínio apontando para o IP público da VPS. Esta etapa é executada **por você** na VPS (o repositório contém apenas os artefatos).

---

## 1. DNS

Escolha um `DOMAIN` raiz (ex.: `empresa.com.br`). Crie registros:

- `A` para `traefik.<DOMAIN>` → IP da VPS  
- `A` para `demo.<DOMAIN>` → IP da VPS  

Alternativa: um único registro curinga `*.sua-sub.empresa.com.br` se o seu provedor DNS suportar.

Aguarde a propagação (TTL).

---

## 2. Colocar o repositório na VPS

Copie ou clone o conteúdo para o diretório desejado (ex.: `~/infra`), mantendo a estrutura:

```text
~/infra/
  .env.example
  .gitignore
  README.md
  docs/
  stacks/
    edge/
      docker-compose.yml
      traefik/
        static/traefik.yml
        dynamic/
    apps/
      demo/
        docker-compose.yml
```

---

## 3. Firewall (se usar UFW)

Na VPS:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

---

## 4. Arquivo `.env`

Na **raiz** de `~/infra` (mesmo nível que `README.md`):

```bash
cd ~/infra
cp .env.example .env
```

Edite `.env`:

- `DOMAIN` — domínio raiz usado nos registros DNS (sem `https://`).
- `ACME_EMAIL` — e-mail válido para Let's Encrypt.

Os `docker-compose.yml` usam `${DOMAIN}` nos **labels** do Traefik. Essa substituição é feita pelo Compose na hora do `up`; use sempre `--env-file` apontando para o `.env` na raiz, como nos comandos das secções 5 e 6.

O serviço Traefik também carrega o mesmo ficheiro via `env_file` para expor `ACME_EMAIL` ao processo (certificados Let's Encrypt).

---

## 5. Subir a borda (Traefik)

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
```

Verifique:

```bash
docker compose ps
docker logs infra_traefik 2>&1 | tail -n 50
```

---

## 6. Subir a aplicação demo

A rede `infra_edge` deve existir (criada pelo passo anterior).

```bash
cd ~/infra/stacks/apps/demo
docker compose --env-file ../../../.env up -d
docker compose ps
```

---

## 7. Validação funcional

1. Navegador: `https://demo.<DOMAIN>` — deve mostrar resposta do `whoami` (hostname do container, cabeçalhos).
2. Certificado: cadeado válido (Let's Encrypt).
3. `http://demo.<DOMAIN>` — deve redirecionar para HTTPS.
4. Opcional: `https://traefik.<DOMAIN>` — dashboard do Traefik (em produção restrinja por firewall ou autenticação numa etapa futura).

Se o certificado falhar, confira: DNS apontando para esta VPS, portas 80 e 443 abertas, relógio da VPS correto (`timedatectl`), e logs do Traefik.

---

## 8. Checklist antes da Etapa 2

- [ ] `https://demo.<DOMAIN>` acessível e com TLS válido.
- [ ] `.env` não está no Git (ver `docs/versionamento-git.md`).
- [ ] Você entende a diferença entre `stacks/edge` (compartilhado) e `stacks/apps/demo` (específico).

---

## O que esta etapa entrega

- **Compartilhado:** Traefik, rede `infra_edge`, emissão de certificados.
- **Por app:** Compose em `stacks/apps/demo` com labels Traefik; novas apps replicam o padrão com outro hostname e outro `docker-compose.yml`.

Próxima evolução sugerida: documentar o template “nova aplicação”, preparar stack **ematricula** (somente pasta `api`) e só depois Jenkins + webhook GitHub.
