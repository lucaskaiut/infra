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

Os `docker-compose.yml` usam `${DOMAIN}` nos **labels** do Traefik. O Compose só carrega esse ficheiro para **interpolação** quando você passa `--env-file` na linha de comando (o `env_file` dentro do YAML alimenta o **container**, não resolve `${DOMAIN}` no próprio YAML).

Por isso, **em `stacks/edge`**, use sempre o mesmo ficheiro em **qualquer** subcomando: `up`, `ps`, `logs`, `down`, `pull`, etc.:

`docker compose --env-file ../../.env <subcomando>`

Em `stacks/apps/demo`, o equivalente é `--env-file ../../../.env`.

**Atalho opcional:** a partir de `~/infra/stacks/edge`, criar um link simbólico `ln -sf ../../.env .env` (o `.env` na raiz continua fora do Git). Com isso, o Compose encontra `.env` no diretório do projeto e `docker compose ps` funciona sem repetir `--env-file`.

Confirme que a raiz tem as variáveis sem espaços à volta do `=`:

`grep -E '^(DOMAIN|ACME_EMAIL)=' ~/infra/.env`

O e-mail do Let's Encrypt é definido no Compose com `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL` (variável oficial do Traefik), interpolado a partir de `ACME_EMAIL` no `.env` — mais fiável do que `${ACME_EMAIL}` dentro do ficheiro `traefik.yml` montado. O `env_file` mantém o restante do `.env` disponível no container.

---

## 5. Subir a borda (Traefik)

```bash
cd ~/infra/stacks/edge
docker compose --env-file ../../.env up -d
```

Verifique:

```bash
docker compose --env-file ../../.env ps
docker logs infra_traefik 2>&1 | tail -n 50
```

Se você acabou de atualizar o repositório (por exemplo passando de Traefik **v3.3** para **v3.6**) ou ainda vê *client version 1.24 is too old* nos logs, force a nova imagem e recrie o container:

```bash
docker compose --env-file ../../.env pull
docker compose --env-file ../../.env up -d
```

Versões antigas do Traefik usam API Docker 1.24 e deixam de funcionar com Docker Engine 29+; **v3.6** negocia a API com o daemon.

---

## 6. Subir a aplicação demo

A rede `infra_edge` deve existir (criada pelo passo anterior).

```bash
cd ~/infra/stacks/apps/demo
docker compose --env-file ../../../.env up -d
docker compose --env-file ../../../.env ps
```

---

## 7. Validação funcional

1. Navegador: `https://demo.<DOMAIN>` — deve mostrar resposta do `whoami` (hostname do container, cabeçalhos).
2. Certificado: cadeado válido (Let's Encrypt).
3. `http://demo.<DOMAIN>` — deve redirecionar para HTTPS.
4. Opcional: `https://traefik.<DOMAIN>` — dashboard do Traefik (em produção restrinja por firewall ou autenticação numa etapa futura).

Se o certificado falhar, confira: DNS apontando para esta VPS, portas 80 e 443 abertas, relógio da VPS correto (`timedatectl`), e logs do Traefik.

### Problemas comuns

| Sintoma | Causa provável | O que fazer |
|--------|----------------|-------------|
| `required variable DOMAIN is missing` ao usar `docker compose ps` | `ps` sem `--env-file` (ou sem `.env` na pasta do projeto) | Usar `docker compose --env-file ../../.env ps` ou o link simbólico `.env` descrito na secção 4. |
| *client version 1.24 is too old. Minimum supported API version is 1.40* (ou 1.44) nos logs do Traefik | Imagem Traefik antiga com cliente Docker API fixo em 1.24 vs Docker Engine 29+ | `docker compose --env-file ../../.env pull` e `up -d` com o `docker-compose.yml` atual (**Traefik v3.6**). |
| *invalidContact* / *unable to parse email address* (ACME) | E-mail vazio no pedido ao Let's Encrypt (expansão de `${ACME_EMAIL}` no YAML falhou) ou `.env` com aspas/CRLF/BOM | Usar o `docker-compose.yml` atual (e-mail via `TRAEFIK_…_ACME_EMAIL`). Confirme com `docker compose --env-file ../../.env exec traefik env \| grep TRAEFIK_CERT`. Linha no `.env` sem aspas: `ACME_EMAIL=mail@dominio.com`. Se editou no Windows: `sed -i 's/\r$//' ~/infra/.env`. |

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
