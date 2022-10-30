Relevant forks: https://github.com/sundayfun/xo/commits/master

- generate separate queries `where deleted_at is null`
and `where deleted_at is not null` with query struct field

- columns where there is a trigger with insert should be excluded
  (instead of manually adding --ignore *.created_at, etc.)

- Use PostgresTableGenerations to exclude these fields
  (`generated always as...`) from insert queries, but include in `returning ...`.

- materialized views are just regular tables, we should be able to use
  exactly the same code but tables to use come from selecting using relkind="m"

- if using --schema flag then force user to pass --enums-pkg flag (TODO) to share sqlc's
  enum in multiple packages. import should always be <last> gith.../<last> for consistency

- replicate sqlc enum gen - also a go template, should be trivial to port to xo
  and disable sqlc enum generation with PR
  for disable_emit_enums.
  this allows for far better extensibility since we cant control sqlc templates

- primary key with uuid should be detected (for other generated cols use
  --ignore instead)

-  if index has WHERE condition it should be reflected in the generated query
   and change method name (right now clashing)

- ~~new --go-postgres-driver flag (pgx|stdlib)~~ (pgx only)

- debugging?

- testing strategy. xo itself has no tests
