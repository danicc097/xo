Relevant forks: https://github.com/sundayfun/xo/commits/master

- remove sqlite. will use a lot of postgres magic and wont find equivalents

- Use PostgresTableGenerations to exclude these fields
  (`generated always as...`) from insert queries, but include in `returning ...`.

- materialized views (same as tables but relkind="m" and generate queries from
  indexes only)

- primary key with uuid should be detected (for other generated cols use
  --ignore instead)

- new --go-postgres-driver flag (pgx|stdlib)

- sqlc will be generated first. xo's package name change to whatever that is
  with `--go-pkg=<name>`(UPDATE: doesn't recognize. use go.go) and output to the same folder. if files found in "-o"
  folder (meaning using sqlc):

  - don't output interface or enum files
  - enums: xo and sqlc need their own. need to adapt **xo**
    usage of enums to use sqlc's (they will be in the same package)

  - TBD what to do with sqlc's models.go extra table models (xo has a more accurate model excluding columns, etc.)

- debugging??