# Serviços partilhados (MySQL + Redis)

Uma única instância de **MySQL** e **Redis** para todas as aplicações que precisem deles. A rede Docker **`infra_shared`** liga estes serviços às stacks em `stacks/apps/*`.

## Ordem de subida

1. `stacks/edge/` (Traefik, rede `infra_edge`)
2. **`stacks/shared/`** (este diretório)
3. Cada aplicação em `stacks/apps/<app>/`

## Configuração

```bash
cd ~/infra/stacks/shared
cp .env.example .env
```

Edite `.env`: `MYSQL_ROOT_PASSWORD` e `EMATRICULA_DB_PASSWORD` (e nome/utilizador da BD se mudar do padrão).

**A password `EMATRICULA_DB_PASSWORD` deve ser a mesma** que `DB_PASSWORD` no `.env` da stack **ematricula** (e de qualquer outra app que use essa BD).

## Subir

```bash
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

## Novas bases de dados / aplicações

Os scripts em `mysql/init/` só correm na **primeira inicialização** do volume MySQL (diretório de dados vazio). Para uma segunda aplicação:

1. Adicionar novo script numerado (ex.: `02-outro-app.sh`) e variáveis no `.env` da stack shared, **ou**
2. Criar BD e utilizador manualmente com `mysql -uroot -p` dentro do container após a primeira subida.

Documente o padrão em `docs/05-servicos-compartilhados.md`.

## Redis e isolamento

Várias apps no mesmo Redis devem usar **prefixos ou bases diferentes** (ex.: `REDIS_PREFIX` no Laravel) para evitar colisão de chaves. A stack eMatricula define `REDIS_PREFIX=ematricula_` no `.env.example`.
