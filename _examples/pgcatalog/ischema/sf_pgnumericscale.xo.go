package ischema

// Code generated by xo. DO NOT EDIT.

import (
	"context"

	"github.com/danicc097/xo/v5/_examples/pgcatalog/pgtypes"
)

// PgNumericScale calls the stored function 'information_schema._pg_numeric_scale(oid, integer) integer' on db.
func PgNumericScale(ctx context.Context, db DB, typid pgtypes.Oid, typmod int) (int, error) {
	// call information_schema._pg_numeric_scale
	const sqlstr = `SELECT * FROM information_schema._pg_numeric_scale($1, $2)`
	// run
	var r0 int
	logf(sqlstr, typid, typmod)
	if err := db.QueryRowContext(ctx, sqlstr, typid, typmod).Scan(&r0); err != nil {
		return 0, logerror(err)
	}
	return r0, nil
}
