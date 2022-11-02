Relevant forks: https://github.com/sundayfun/xo/commits/master


- materialized view uses a view -> xo generates all fields as nullable
(is this intended?)

- joins for o2m, m2m, o2o

- (not that worth it) replicate sqlc enum gen - also a go template, should be trivial to port to xo
  and disable sqlc enum generation with PR
  for disable_emit_enums.
  this allows for far better extensibility since we cant control sqlc templates.

- (is this even necessary) columns where there is a trigger with insert should be excluded
  (instead of manually adding --ignore *.created_at, etc.).
  only workaround so far is reading the source code for the trigger
  and check where there's a ``/new.(.*?)\s=/i`` -> match group column.
  But imagine new.* = new.* || 'something', then its not doing what we want.

- testing strategy. xo itself has no tests
