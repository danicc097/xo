package models

// Code generated by xo. DO NOT EDIT.

import (
	"context"
)

// Enum is a enum.
type Enum struct {
	EnumName string `json:"enum_name"` // enum_name
	Schema string  `json:"schema"`
}

// PostgresEnums runs a custom query, returning results as Enum.
func PostgresEnums(ctx context.Context, db DB, schema string) ([]*Enum, error) {
	// query
	const sqlstr = `SELECT ` +
		`DISTINCT t.typname ` + // ::varchar AS enum_name
		`FROM pg_type t ` +
		`JOIN ONLY pg_namespace n ON n.oid = t.typnamespace ` +
		`JOIN ONLY pg_enum e ON t.oid = e.enumtypid ` +
		`WHERE n.nspname = $1`
	// run
	logf(sqlstr, schema)
	rows, err := db.QueryContext(ctx, sqlstr, schema)
	if err != nil {
		return nil, logerror(err)
	}
	defer rows.Close()
	// load results
	var res []*Enum
	for rows.Next() {
		var e Enum
		// scan
		if err := rows.Scan(&e.EnumName); err != nil {
			return nil, logerror(err)
		}
		res = append(res, &e)
	}
	if err := rows.Err(); err != nil {
		return nil, logerror(err)
	}
	return res, nil
}
