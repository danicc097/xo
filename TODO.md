Relevant forks: https://github.com/sundayfun/xo/commits/master

- columns where there is a trigger with insert should be excluded
  (instead of manually adding --ignore *.created_at, etc.)

- materialized views are just regular tables, we should be able to use
  exactly the same code but tables to use come from selecting using relkind="m"

- dynamic `orderBy UserOrderBy` options struct field if index found for
  timestamp column. Get appended after any select if present and can be
  combined:
  order by updated_at desc, created_at desc,
 `type UserOrderBy = string , UserCreatedAtDesc UserOrderBy = "UserCreatedAtDesc" `

- if using --schema flag then force user to pass --enums-pkg flag (TODO) to share sqlc's
  enum in multiple packages. import should always be <last> gith.../<last> for
  consistency
  if enums-pkg is set then prepend {pkg}.{enumName} everywhere

- replicate sqlc enum gen - also a go template, should be trivial to port to xo
  and disable sqlc enum generation with PR
  for disable_emit_enums.
  this allows for far better extensibility since we cant control sqlc templates

- testing strategy. xo itself has no tests
