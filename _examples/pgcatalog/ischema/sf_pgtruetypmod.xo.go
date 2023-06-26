package ischema

// Code generated by xo. DO NOT EDIT.

import (
	"context"

	"github.com/danicc097/xo/v3/_examples/pgcatalog/pgtypes"
)

// PgTruetypmod calls the stored function 'information_schema._pg_truetypmod(pg_attribute, pg_type) integer' on db.
func PgTruetypmod(ctx context.Context, db DB, p0 pgtypes.PgAttribute, p1 pgtypes.PgType) (int, error) {
	// call information_schema._pg_truetypmod
	const sqlstr = `SELECT * FROM information_schema._pg_truetypmod($1, $2)`
	// run
	var r0 int
	logf(sqlstr, p0, p1)
	if err := db.QueryRowContext(ctx, sqlstr, p0, p1).Scan(&r0); err != nil {
		return 0, logerror(err)
	}
	return r0, nil
}
