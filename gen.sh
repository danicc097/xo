#!/bin/bash

#
# Prerequisites: go install github.com/traefik/yaegi/cmd/yaegi
# Usage: bash gen.sh ./models/ && go generate ./...
#
# If models are wrongly generated and xo gets built: revert changes, build again (else XOBIN will never generate back)
#

set -a
source .env
set +a

docker-compose up -d --build

PGDB="pg://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"

DEST=$1
if [ -z "$DEST" ]; then
  echo "usage: $0 <DEST>"
  exit 1
fi
shift

XOBIN=$(which xo)
if [ -e ./xo ]; then
  XOBIN=./xo
fi
XOBIN=$(realpath $XOBIN)

set -e

mkdir -p "$DEST"
rm -f ./*.db
rm -rf "$DEST"/*.xo.go

# postgres view create query
COMMENT='{{ . }} creates a view for introspection.'
$XOBIN query "$PGDB" -M -B -X -F PostgresViewCreate --func-comment "$COMMENT" --single=models.xo.go -I -o "$DEST" "$@" <<ENDSQL
/* %%schema string,interpolate%% */
CREATE TEMPORARY VIEW %%id string,interpolate%% AS %%query []string,interpolate,join%%
ENDSQL

# postgres view schema query
COMMENT='{{ . }} retrieves the schema for a view created for introspection.'
$XOBIN query "$PGDB" -M -B -l -F PostgresViewSchema --func-comment "$COMMENT" --single=models.xo.go -I -a -o "$DEST" "$@" <<ENDSQL
SELECT
  n.nspname::varchar AS schema_name
FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname LIKE 'pg_temp%'
  AND c.relname = %%id string%%
ENDSQL

# postgres view drop query
COMMENT='{{ . }} drops a view created for introspection.'
$XOBIN query "$PGDB" -M -B -X -F PostgresViewDrop --func-comment "$COMMENT" --single=models.xo.go -I -a -o "$DEST" "$@" <<ENDSQL
/* %%schema string,interpolate%% */
DROP VIEW %%id string,interpolate%%
ENDSQL

# postgres schema query
COMMENT='{{ . }} retrieves the schema.'
$XOBIN query "$PGDB" -M -B -l -F PostgresSchema --func-comment "$COMMENT" --single=models.xo.go -a -o "$DEST" "$@" <<ENDSQL
SELECT
  CURRENT_SCHEMA()::varchar AS schema_name
ENDSQL

# postgres enum list query
COMMENT='{{ . }} is a enum.'
$XOBIN query "$PGDB" -M -B -2 -T Enum -F PostgresEnums --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  DISTINCT t.typname::varchar AS enum_name,
  n.nspname AS schema
FROM pg_type t
  JOIN ONLY pg_namespace n ON n.oid = t.typnamespace
  JOIN ONLY pg_enum e ON t.oid = e.enumtypid
WHERE n.nspname = %%schema string%%
ENDSQL

# postgres enum value list query
COMMENT='{{ . }} is a enum value.'
$XOBIN query "$PGDB" -M -B -2 -T EnumValue -F PostgresEnumValues --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  e.enumlabel::varchar AS enum_value,
  e.enumsortorder::integer AS const_value
FROM pg_type t
  JOIN ONLY pg_namespace n ON n.oid = t.typnamespace
  LEFT JOIN pg_enum e ON t.oid = e.enumtypid
WHERE n.nspname = %%schema string%%
  AND t.typname = %%enum string%%
ENDSQL

# postgres proc list query
COMMENT='{{ . }} is a stored procedure.'
$XOBIN query "$PGDB" -M -B -2 -T Proc -F PostgresProcs --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  p.oid::varchar AS proc_id,
  p.proname::varchar AS proc_name,
  pp.proc_type::varchar AS proc_type,
  format_type(pp.return_type, NULL)::varchar AS return_type,
  pp.return_name::varchar AS return_name,
  p.prosrc::varchar AS proc_def
FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON (p.pronamespace = n.oid)
  JOIN (
    SELECT
      p.oid,
      (CASE WHEN EXISTS(
          SELECT
            column_name
          FROM information_schema.columns
          WHERE table_name = 'pg_proc'
            AND column_name = 'prokind'
        )
        THEN (CASE p.prokind
          WHEN 'p' THEN 'procedure'
          WHEN 'f' THEN 'function'
        END)
        ELSE ''
      END) AS proc_type,
      UNNEST(COALESCE(p.proallargtypes, ARRAY[p.prorettype])) AS return_type,
      UNNEST(CASE
        WHEN p.proargmodes IS NULL THEN ARRAY['']
        ELSE p.proargnames
      END) AS return_name,
      UNNEST(COALESCE(p.proargmodes, ARRAY['o'])) AS param_type
    FROM pg_catalog.pg_proc p
  ) AS pp ON p.oid = pp.oid
WHERE p.prorettype <> 'pg_catalog.cstring'::pg_catalog.regtype
  AND (p.proargtypes[0] IS NULL
    OR p.proargtypes[0] <> 'pg_catalog.cstring'::pg_catalog.regtype)
  AND (pp.proc_type = 'function'
    OR pp.proc_type = 'procedure')
  AND pp.param_type = 'o'
  AND n.nspname = %%schema string%%
ENDSQL

# postgres proc parameter list query
COMMENT='{{ . }} is a stored procedure param.'
$XOBIN query "$PGDB" -M -B -2 -T ProcParam -F PostgresProcParams --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  COALESCE(pp.param_name, '')::varchar AS param_name,
  pp.param_type::varchar AS param_type
FROM pg_proc p
  JOIN ONLY pg_namespace n ON p.pronamespace = n.oid
  JOIN (
    SELECT
      p.oid,
      UNNEST(p.proargnames) AS param_name,
      format_type(UNNEST(p.proargtypes), NULL) AS param_type
    FROM pg_proc p
  ) AS pp ON p.oid = pp.oid
WHERE n.nspname = %%schema string%%
  AND p.oid::varchar = %%id string%%
  AND pp.param_type IS NOT NULL
ENDSQL

# postgres table list query
COMMENT='{{ . }} is a table.'
$XOBIN query "$PGDB" -M -B -2 -T Table -F PostgresTables --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  (CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'mat_view'
  END)::varchar AS type,
  c.relname::varchar AS table_name,
  false::boolean AS manual_pk,
  CASE c.relkind
    WHEN 'r' THEN ''
    WHEN 'v' THEN v.definition
    WHEN 'm' THEN ''
  END AS view_def,
  CASE c.relkind
    WHEN 'r' THEN ''
    WHEN 'v' THEN ''
    WHEN 'm' THEN m.definition
  END AS matview_def
FROM pg_class c
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_views v ON n.nspname = v.schemaname
    AND v.viewname = c.relname
  LEFT JOIN pg_matviews m ON n.nspname = m.schemaname
WHERE n.nspname = %%schema string%%
  AND (CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'mat_view'
  END) = LOWER(%%typ string%%)
ENDSQL

# postgres table column list query
FIELDS='FieldOrdinal int,ColumnName string,DataType string,NotNull bool,DefaultValue sql.NullString,IsPrimaryKey bool,ColumnComment string'
COMMENT='{{ . }} is a column.'
$XOBIN query "$PGDB" -M -B -2 -T Column -F PostgresTableColumns -Z "$FIELDS" --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT DISTINCT
  a.attnum::integer AS field_ordinal,
  a.attname::varchar AS column_name,
  format_type(a.atttypid, a.atttypmod)::varchar AS data_type,
  a.attnotnull::boolean AS not_null,
  COALESCE(pg_get_expr(ad.adbin, ad.adrelid), '')::varchar AS default_value,
  COALESCE(ct.contype = 'p', false)::boolean AS is_primary_key,
  COALESCE(col_description(format('%s.%s', n.nspname, c.relname)::regclass::oid, isc.ordinal_position), '') as column_comment
FROM pg_attribute a
  JOIN ONLY pg_class c ON c.oid = a.attrelid
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  INNER JOIN information_schema.columns as isc on c.relname = isc.table_name and isc.column_name = a.attname
  LEFT JOIN pg_constraint ct ON ct.conrelid = c.oid
    AND a.attnum = ANY(ct.conkey)
    AND ct.contype = 'p'
  LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid
    AND ad.adnum = a.attnum
WHERE a.attisdropped = false
  AND n.nspname = %%schema string%%
  AND c.relname = %%table string%%
  AND (%%sys bool%% OR a.attnum > 0)
ORDER BY field_ordinal
ENDSQL

# postgres sequence list query
COMMENT='{{ . }} is a sequence.'
$XOBIN query "$PGDB" -M -B -2 -T Sequence -F PostgresTableSequences --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  a.attname::varchar as column_name
FROM pg_class s
  JOIN pg_depend d ON d.objid = s.oid
  JOIN pg_class t ON d.objid = s.oid AND d.refobjid = t.oid
  JOIN pg_attribute a ON (d.refobjid, d.refobjsubid) = (a.attrelid, a.attnum)
  JOIN pg_namespace n ON n.oid = s.relnamespace
WHERE s.relkind = 'S'
  AND n.nspname = %%schema string%%
  AND t.relname = %%table string%%
ENDSQL

# postgres generated columns list query
COMMENT='{{ . }} represents generated columns.'
$XOBIN query "$PGDB" -M -B -2 -T Generated -F PostgresTableGenerations --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  column_name
FROM information_schema.columns
WHERE table_schema = %%schema string%%
  and table_name = %%table string%%
  and is_generated = 'ALWAYS'
ENDSQL

# -------------------------------------------------------

# postgres proc list query
COMMENT='{{ . }} represents all constraints in a schema.'
$XOBIN query "$PGDB" -M -B -2 -T Constraint -F PostgresConstraints --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  distinct (CASE tc.constraint_type
    WHEN 'UNIQUE' THEN 'unique'
    WHEN 'CHECK' THEN 'check'
    WHEN 'PRIMARY KEY' THEN 'primary_key'
    WHEN 'FOREIGN KEY' THEN 'foreign_key'
  END)::varchar AS key_type,
  tc.constraint_name::varchar AS unique_key_name,
  tc.table_name as table_name,
  kcu.column_name::varchar AS column_name,
  COALESCE(obj_description(format('%s.%s',c.table_schema,c.table_name)::regclass::oid, 'pg_class'), '') as table_comment,
  COALESCE(col_description(format('%s.%s',c.table_schema,c.table_name)::regclass::oid, c.ordinal_position), '') as column_comment,
  ccu.table_name::varchar AS ref_table_name,
  ccu.column_name::varchar AS ref_column_name
FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
  join information_schema.columns as c on tc.table_name = c.table_name and c.column_name = kcu.column_name
  JOIN (
    SELECT
      ROW_NUMBER() OVER (
        PARTITION BY
          table_schema,
          table_name,
          constraint_name
        ORDER BY row_num
      ) AS ordinal_position,
      table_schema,
      table_name,
      column_name,
      constraint_name
    FROM (
      SELECT
        ROW_NUMBER() OVER (ORDER BY 1) AS row_num,
        table_schema,
        table_name,
        column_name,
        constraint_name
      FROM information_schema.constraint_column_usage
    ) t
  ) AS ccu ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
    AND ccu.ordinal_position = kcu.ordinal_position
WHERE tc.table_schema = %%schema string%%
ENDSQL

# TODO discover foreign keys in other tables for the current pk pk1:
# and allow for optional join with discovered lookup tables and return json_agg of the recursively joined fks
# example:
# users, user_organization, organizations -> queries for users.xo.go
# have struct parameter for selects only: UserJoins{JoinOrganization: boolean, ...}
# we don't need to generate rows to select from the join. we can use json_agg(o.*)).
# because when we unmarshal into Organization struct excluded fields are not in the struct already.
# NOTE: because we know the json fields in advanced, we can work with []byte returned by json_agg
# see https://www.alexedwards.net/blog/using-postgresql-jsonb

# to discover specific relation types (o2m, m2m, o2o) maybe checkout `ent`

# viewing pk used as foreign keys:
# SELECT
#     tc.table_schema,
#     tc.constraint_name,
#     tc.table_name,
#     kcu.column_name,
#     ccu.table_schema AS foreign_table_schema,
#     ccu.table_name AS foreign_table_name,
#     ccu.column_name AS foreign_column_name
# FROM
#     information_schema.table_constraints AS tc
#     JOIN information_schema.key_column_usage AS kcu
#       ON tc.constraint_name = kcu.constraint_name
#       AND tc.table_schema = kcu.table_schema
#     JOIN information_schema.constraint_column_usage AS ccu
#       ON ccu.constraint_name = tc.constraint_name
#       AND ccu.table_schema = tc.table_schema
# WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='<table>';

# better solution:
# select relations.table_name as table_name,
#        array_remove( array_agg(relations.table_name), NULL) as relationships,
#        array_remove( array_agg(relations.referenced_tables), NULL) as foreign_keys,
#        array_remove( array_agg(relations.referencing_tables), NULL) as references,
#        array_remove( array_agg(distinct related_table), NULL) as related_tables,
#        array_remove( array_agg(distinct relations.referenced_tables), NULL) as referenced_tables,
#        array_remove( array_agg(distinct relations.referencing_tables), NULL) as referencing_tables
# from(
#      select pk_tco.table_schema || '.' || pk_tco.table_name as table_name,
#             fk_tco.table_schema || '.' || fk_tco.table_name as related_table,
#             fk_tco.table_name as referencing_tables,
#             null::varchar(100) as referenced_tables
#      from information_schema.referential_constraints rco
#      join information_schema.table_constraints fk_tco
#           on rco.constraint_name = fk_tco.constraint_name
#           and rco.constraint_schema = fk_tco.table_schema
#      join information_schema.table_constraints pk_tco
#           on rco.unique_constraint_name = pk_tco.constraint_name
#           and rco.unique_constraint_schema = pk_tco.table_schema
#     union all
#     select fk_tco.table_schema || '.' || fk_tco.table_name as table_name,
#            pk_tco.table_schema || '.' || pk_tco.table_name as related_table,
#            null as referencing_tables,
#            pk_tco.table_name as referenced_tables
#     from information_schema.referential_constraints rco
#     join information_schema.table_constraints fk_tco
#          on rco.constraint_name = fk_tco.constraint_name
#          and rco.constraint_schema = fk_tco.table_schema
#     join information_schema.table_constraints pk_tco
#          on rco.unique_constraint_name = pk_tco.constraint_name
#          and rco.unique_constraint_schema = pk_tco.table_schema
# ) relations
# group by table_name
# order by relationships desc;
# | table_name              | relationships                                      | foreign_keys         | references                  | related_tables                            | referenced_tables    | referencing_tables
# | ----------              | -------------                                      | ------------         | ----------                  | --------------                            | -----------------    | ------------------
# | public.users            | {public.users,public.users}                        | {}                   | {api_keys,user_organization}| {public.api_keys,public.user_organization}| {}                   | {api_keys,user_organization}
# | public.user_organization| {public.user_organization,public.user_organization}| {organizations,users}| {}                          | {public.organizations,public.users}       | {organizations,users}| {}
# | public.projects         | {public.projects}                                  | {organizations}      | {}                          | {public.organizations}                    | {organizations}      | {}
# | public.organizations    | {public.organizations,public.organizations}        | {}                   | {user_organization,projects}| {public.projects,public.user_organization}| {}                   | {projects,user_organization}
# | public.api_keys         | {public.api_keys}                                  | {users}              | {}                          | {public.users}                            | {users}              | {}
# |                         |                                                    |                      |                             |                                           |                      |

# + check comment /cardinality:(.*),/ and exit if found cardinality not in (O2M,M2M,O2O)

# -------------------------------------------------------

# postgres trigger columns list query
# COMMENT='{{ . }} represents trigger generated/updated columns.'
# $XOBIN query "$PGDB" -M -B -2 -T Triggered -F PostgresTableTriggers --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
# TODO get affected rows from source case insens. (new.(.*)\s=)
# -- get trigger name per schema and table (we get source but its EXECUTE ...)
# /*select event_object_schema as table_schema,
#        event_object_table as table_name,
#        trigger_schema,
#        trigger_name,
#        string_agg(event_manipulation, ',') as event,
#        action_timing as activation,
#        action_condition as condition,
#        action_statement as definition
# from information_schema.triggers
# group by 1,2,3,4,6,7,8
# order by table_schema,
#          table_name;*/
# ENDSQL

# // TODO start with tc.constraint_type = 'FOREIGN KEY' query
# then we a bunch of rows, e.g. ref_column_name is team_id, fk name 'user_team_pkey' -->
# find origin table where pk is team_id:
#   tc.constraint_type = 'PRIMARY KEY'
# and ccu.column_name = 'team_id' (previous query's ccu.column_name)
# and tc.constraint_name != 'user_team_pkey' (previous query's tc.constraint_name)
# | foreign_key_name| table_name| column_name| ref_table_name| ref_column_name| key_id
# | ----------------| ----------| -----------| --------------| ---------------| ------
# | teams_pkey      | teams     | team_id    | teams         | team_id        | 0
# so we join on teams (by team_id) for every row returned from the other join with user_team (by user_id).
# if result count from pk query is > 1 do another subjoin again
# postgres table foreign key list query
COMMENT='{{ . }} is a foreign key.'
$XOBIN query "$PGDB" -M -B -2 -T ForeignKey -F PostgresTableForeignKeys --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  tc.constraint_name::varchar AS foreign_key_name,
  tc.table_name as table_name,
  kcu.column_name::varchar AS column_name,
  ccu.table_name::varchar AS ref_table_name,
  ccu.column_name::varchar AS ref_column_name,
  0::integer AS key_id
FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
  JOIN (
    SELECT
      ROW_NUMBER() OVER (
        PARTITION BY
          table_schema,
          table_name,
          constraint_name
        ORDER BY row_num
      ) AS ordinal_position,
      table_schema,
      table_name,
      column_name,
      constraint_name
    FROM (
      SELECT
        ROW_NUMBER() OVER (ORDER BY 1) AS row_num,
        table_schema,
        table_name,
        column_name,
        constraint_name
      FROM information_schema.constraint_column_usage
    ) t
  ) AS ccu ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
    AND ccu.ordinal_position = kcu.ordinal_position
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = %%schema string%%
  AND tc.table_name = %%table string%%
ENDSQL
# | foreign_key_name                        | column_name    | ref_table_name| ref_column_name| key_id
# | ----------------                        | -----------    | --------------| ---------------| ------
# | projects_organization_id_fkey           | organization_id| organizations | organization_id| 0
# | user_project_project_id_fkey            | project_id     | projects      | project_id     | 0
# | user_project_user_id_fkey               | user_id        | users         | user_id        | 0
# | task_member_member_fkey                 | member         | users         | user_id        | 0
# | work_item_task_task_id_fkey             | task_id        | tasks         | task_id        | 0
# | work_item_task_work_item_id_fkey        | work_item_id   | work_items    | work_item_id   | 0
# | kanban_steps_project_id_fkey            | project_id     | projects      | project_id     | 0
# | project_kanban_steps_kanban_step_id_fkey| kanban_step_id | kanban_steps  | kanban_step_id | 0
# | project_kanban_steps_project_id_fkey    | project_id     | projects      | project_id     | 0
# | api_keys_user_id_fkey                   | user_id        | users         | user_id        | 0

# postgres table index list query
COMMENT='{{ . }} is a index.'
$XOBIN query "$PGDB" -M -B -2 -T Index -F PostgresTableIndexes --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
select distinct
    pg_indexes.indexdef as index_definition
    , ic.relname::varchar as index_name
    , i.indisunique::boolean as is_unique
    , i.indisprimary::boolean as is_primary
  from
    pg_index i
    join only pg_class c on c.oid = i.indrelid
    join only pg_namespace n on n.oid = c.relnamespace
    join only pg_class ic on ic.oid = i.indexrelid
  join pg_indexes on ic.relname = pg_indexes.indexname
  where
    i.indkey <> '0'
    AND n.nspname = %%schema string%%
    AND c.relname = %%table string%%
ENDSQL

# postgres index column list query
COMMENT='{{ . }} is a index column.'
$XOBIN query "$PGDB" -M -B -2 -T IndexColumn -F PostgresIndexColumns --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  (row_number() over())::integer AS seq_no,
  a.attnum::integer AS cid,
  a.attname::varchar AS column_name
FROM pg_index i
  JOIN ONLY pg_class c ON c.oid = i.indrelid
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  JOIN ONLY pg_class ic ON ic.oid = i.indexrelid
  LEFT JOIN pg_attribute a ON i.indrelid = a.attrelid
    AND a.attnum = ANY(i.indkey)
    AND a.attisdropped = false
WHERE i.indkey <> '0'
  AND n.nspname = %%schema string%%
  AND ic.relname = %%index string%%
ENDSQL

# postgres index column order query
COMMENT='{{ . }} is a index column order.'
$XOBIN query "$PGDB" -M -B -1 -2 -T PostgresColOrder -F PostgresGetColOrder --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  i.indkey::varchar AS ord
FROM pg_index i
  JOIN ONLY pg_class c ON c.oid = i.indrelid
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  JOIN ONLY pg_class ic ON ic.oid = i.indexrelid
WHERE n.nspname = %%schema string%%
  AND ic.relname = %%index string%%
ENDSQL
