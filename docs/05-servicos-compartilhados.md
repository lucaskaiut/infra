# Serviços partilhados — MySQL e Redis

## Requisito de arquitetura

MySQL e Redis são **recursos partilhados** da infraestrutura: **um container MySQL** e **um container Redis** servem **todas** as aplicações que precisem deles, em vez de duplicar por stack.

- **Onde:** `stacks/shared/` (Compose `infra-shared`).
- **Rede:** `infra_shared` (as apps ligam-se como rede `external`).
- **DNS interno:** `mysql` e `redis` (nomes dos serviços no Compose da stack shared).

A stack **edge** continua isolada na `infra_edge` (proxy). As apps que precisam de HTTP público ligam a **duas** redes: `infra_edge` + `infra_shared`.

## Ordem operacional

1. Subir **edge** (`stacks/edge/`).
2. Subir **shared** (`stacks/shared/`).
3. Subir cada **app** (`stacks/apps/<slug>/`).

Sem o shared a correr, as apps que dependem de MySQL/Redis falham ou ficam à espera (ex.: entrypoint da eMatricula à espera do MySQL).

## Variáveis e segredos

- Ficheiro **`.env` em `stacks/shared/`** (não versionado): `MYSQL_ROOT_PASSWORD`, credenciais da BD criada no init (ex.: `EMATRICULA_DB_*`).
- Cada app mantém o seu **`.env`** com `DB_HOST=mysql`, `REDIS_HOST=redis`, e passwords **alinhadas** com o que foi definido no shared (ex.: `DB_PASSWORD` = `EMATRICULA_DB_PASSWORD`).

## MySQL: novas bases e utilizadores

Os ficheiros em `stacks/shared/mysql/init/` executam-se **apenas** na primeira criação do volume de dados do MySQL. Para acrescentar outra aplicação:

- Adicionar um novo script numerado (`02-...sh`) e as respetivas variáveis no `.env` do shared, **ou**
- Executar `CREATE DATABASE` / `CREATE USER` manualmente dentro do container.

## Redis: isolamento entre apps

Todas as apps usam o mesmo processo Redis. Configure **prefixos** ou **bases lógicas** na aplicação (ex.: Laravel `REDIS_PREFIX`) para não colidir chaves, filas e cache entre projetos.

## Migração a partir de MySQL/Redis por app

Se já existia MySQL na stack **ematricula** com dados:

1. **Backup:** `mysqldump` (ou export) a partir do container/volume antigo.
2. **Parar** a stack da app antiga e **subir** `stacks/shared` (volume novo → corre `init`).
3. **Importar** o dump para o MySQL partilhado (ou recriar dados).
4. **Remover** volumes órfãos antigos só depois de confirmar que o backup está seguro.

Não apagar volumes de produção sem backup explícito.

Após mover uma app de MySQL/Redis “embutidos” para o shared, podem ficar **contentores órfãos** (`infra_<app>_mysql`, etc.). Remova-os com `docker rm -f <nome>` ou suba a stack da app com `docker compose up -d --remove-orphans` uma vez.
