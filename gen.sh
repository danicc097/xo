#!/bin/bash

#
# Usage: bash gen.sh ./models/
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
  DISTINCT t.typname::varchar AS enum_name
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
  END)::varchar AS type,
  c.relname::varchar AS table_name,
  false::boolean AS manual_pk,
  CASE c.relkind
    WHEN 'r' THEN ''
    WHEN 'v' THEN v.definition
  END AS view_def
FROM pg_class c
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_views v ON n.nspname = v.schemaname
    AND v.viewname = c.relname
WHERE n.nspname = %%schema string%%
  AND (CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'v' THEN 'view'
  END) = LOWER(%%typ string%%)
ENDSQL

# postgres table column list query
FIELDS='FieldOrdinal int,ColumnName string,DataType string,NotNull bool,DefaultValue sql.NullString,IsPrimaryKey bool'
COMMENT='{{ . }} is a column.'
$XOBIN query "$PGDB" -M -B -2 -T Column -F PostgresTableColumns -Z "$FIELDS" --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  a.attnum::integer AS field_ordinal,
  a.attname::varchar AS column_name,
  format_type(a.atttypid, a.atttypmod)::varchar AS data_type,
  a.attnotnull::boolean AS not_null,
  COALESCE(pg_get_expr(ad.adbin, ad.adrelid), '')::varchar AS default_value,
  COALESCE(ct.contype = 'p', false)::boolean AS is_primary_key
FROM pg_attribute a
  JOIN ONLY pg_class c ON c.oid = a.attrelid
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_constraint ct ON ct.conrelid = c.oid
    AND a.attnum = ANY(ct.conkey)
    AND ct.contype = 'p'
  LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid
    AND ad.adnum = a.attnum
WHERE a.attisdropped = false
  AND n.nspname = %%schema string%%
  AND c.relname = %%table string%%
  AND (%%sys bool%% OR a.attnum > 0)
ORDER BY a.attnum
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
WHERE table_name = %%table string%%
  and table_schema = %%schema string%%
  and is_generated = 'ALWAYS'
ENDSQL

# postgres trigger columns list query
# COMMENT='{{ . }} represents trigger generated/updated columns.'
# $XOBIN query "$PGDB" -M -B -2 -T Triggered -F PostgresTableTriggers --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
# /*
# TODO get affected rows from source case insens. (new.(.*)\s=)
# */
# /*
# SELECT routines.specific_name,  routine_definition
# FROM information_schema.routines
#     LEFT JOIN information_schema.parameters ON routines.specific_name=parameters.specific_name
# WHERE routines.specific_schema='public'
# ORDER BY routines.routine_name, parameters.ordinal_position;
# */

# /*
# SELECT format('%I.%I(%s)', ns.nspname, p.proname, oidvectortypes(p.proargtypes)), *
# FROM pg_proc p INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
# WHERE ns.nspname = 'public';*/

# /*SELECT
#     n.nspname AS function_schema,
#     p.proname AS function_name,
#     p.prosrc as source,
# FROM
#     pg_proc p
#     LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
# WHERE
#     n.nspname NOT IN ('pg_catalog', 'information_schema')
# ORDER BY
#     function_schema,
#     function_name;*/

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

# postgres table foreign key list query
COMMENT='{{ . }} is a foreign key.'
$XOBIN query "$PGDB" -M -B -2 -T ForeignKey -F PostgresTableForeignKeys --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  tc.constraint_name::varchar AS foreign_key_name,
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

# postgres table index list query
COMMENT='{{ . }} is a index.'
$XOBIN query "$PGDB" -M -B -2 -T Index -F PostgresTableIndexes --type-comment "$COMMENT" -o "$DEST" "$@" <<ENDSQL
SELECT
  DISTINCT ic.relname::varchar AS index_name,
  i.indisunique::boolean AS is_unique,
  i.indisprimary::boolean AS is_primary
FROM pg_index i
  JOIN ONLY pg_class c ON c.oid = i.indrelid
  JOIN ONLY pg_namespace n ON n.oid = c.relnamespace
  JOIN ONLY pg_class ic ON ic.oid = i.indexrelid
WHERE i.indkey <> '0'
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
