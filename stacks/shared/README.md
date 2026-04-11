# Serviços partilhados (MySQL + Redis)

Uma única instância de **MySQL** e **Redis** para todas as aplicações que precisem deles. A rede Docker **`infra_shared`** liga estes serviços às stacks em `stacks/apps/*`.

Nada nesta stack referencia uma app concreta: nomes de base, utilizador e passwords vêm só do teu `.env`.

## Ordem de subida

1. `stacks/edge/` (Traefik, rede `infra_edge`)
2. **`stacks/shared/`** (este diretório)
3. Cada aplicação em `stacks/apps/<app>/`

## Configuração

```bash
cd ~/infra/stacks/shared
cp .env.example .env
```

Edite `.env`:

- `MYSQL_ROOT_PASSWORD` — root do MySQL.
- `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` — base e utilizador criados **na primeira inicialização** do volume (imagem oficial MySQL). Cada aplicação que use esta base deve ter no **seu** `.env` os mesmos `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` (ou equivalente).

## Subir

```bash
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

## Mais bases ou utilizadores

A imagem cria **uma** base + utilizador no primeiro arranque com volume vazio. Para outras BDs:

- `mysql -uroot -p` dentro do container, **ou**
- montar scripts em `docker-entrypoint-initdb.d` (adicionar volume e ficheiros `.sql`/`.sh` ao `docker-compose.yml` quando precisares).

## Redis e isolamento

Várias apps no mesmo Redis devem usar **prefixos ou bases lógicas** na aplicação (ex.: Laravel `REDIS_PREFIX`) para evitar colisão de chaves.
