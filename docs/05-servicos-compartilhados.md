# Serviços partilhados — MySQL e Redis

## Requisito de arquitetura

MySQL e Redis são **recursos partilhados** da infraestrutura: **um container MySQL** e **um container Redis** servem **todas** as aplicações que precisem deles, em vez de duplicar por stack.

- **Onde:** `stacks/shared/` (Compose `infra-shared`).
- **Rede:** `infra_shared` (as apps ligam-se como rede `external`).
- **DNS interno:** `mysql` e `redis` (nomes dos serviços no Compose da stack shared).

A stack **shared** não deve conter nomes de aplicações: só variáveis genéricas (`MYSQL_*`, volume Redis). Quem define o nome da base e utilizador é o `.env` do servidor, alinhado com cada app.

A stack **edge** continua isolada na `infra_edge` (proxy). As apps que precisam de HTTP público ligam a **duas** redes: `infra_edge` + `infra_shared`.

## Ordem operacional

1. Subir **edge** (`stacks/edge/`).
2. Subir **shared** (`stacks/shared/`).
3. Subir cada **app** (`stacks/apps/<slug>/`).

Sem o shared a correr, as apps que dependem de MySQL/Redis falham ou ficam à espera.

## Variáveis e segredos

- **`.env` em `stacks/shared/`** (não versionado): `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` (criação inicial da base na imagem oficial).
- Cada app mantém o seu **`.env`** com `DB_HOST=mysql`, `REDIS_HOST=redis`, e **`DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` iguais** aos `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` do shared (quando usar essa base).

## MySQL: novas bases e utilizadores

A imagem oficial cria **uma** base + utilizador no primeiro arranque. Para mais BDs: SQL manual no container ou scripts em `docker-entrypoint-initdb.d` (ver `stacks/shared/mysql/README.md`).

## Redis: isolamento entre apps

Todas as apps usam o mesmo processo Redis. Configure **prefixos** ou **bases lógicas** na aplicação (ex.: Laravel `REDIS_PREFIX`) para não colidir chaves, filas e cache entre projetos.

## Migração a partir de MySQL por app

1. **Backup** (`mysqldump` ou equivalente).
2. Parar a app antiga e subir **shared** (volume novo → primeira inicialização com `MYSQL_*`).
3. Importar o dump se necessário.
4. Remover contentores/volumes órfãos só após confirmar backup.

Não apagar volumes de produção sem backup explícito.

Após mover uma app de MySQL “embutido” para o shared, podem ficar **contentores órfãos**. Remova-os com `docker rm -f <nome>` ou `docker compose up -d --remove-orphans` na stack da app.

## Renomear variáveis no `.env` do servidor

Se ainda tiveres no `.env` do shared nomes antigos (`EMATRICULA_DB_*`), renomeia para `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` e volta a subir o MySQL **só** se puderes recriar o volume ou migrar dados — alterar só o `.env` não recria a base num volume já inicializado.
