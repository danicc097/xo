package models

// Code generated by xo. DO NOT EDIT.

import (
	"context"
)

// ForeignKey is a foreign key.
type ForeignKey struct {
	ForeignKeyName string `json:"foreign_key_name"` // foreign_key_name
	ColumnName     string `json:"column_name"`      // column_name
	RefTableName   string `json:"ref_table_name"`   // ref_table_name
	RefColumnName  string `json:"ref_column_name"`  // ref_column_name
	KeyID          int    `json:"key_id"`           // key_id
}

// PostgresTableForeignKeys runs a custom query, returning results as ForeignKey.
func PostgresTableForeignKeys(ctx context.Context, db DB, schema, table string) ([]*ForeignKey, error) {
	// query
	const sqlstr = `SELECT ` +
		`tc.constraint_name, ` + // ::varchar AS foreign_key_name
		`kcu.column_name, ` + // ::varchar AS column_name
		`ccu.table_name, ` + // ::varchar AS ref_table_name
		`ccu.column_name, ` + // ::varchar AS ref_column_name
		`0 ` + // ::integer AS key_id
		`FROM information_schema.table_constraints tc ` +
		`JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name ` +
		`AND tc.table_schema = kcu.table_schema ` +
		`JOIN ( ` +
		`SELECT ` +
		`ROW_NUMBER() OVER ( ` +
		`PARTITION BY ` +
		`table_schema, ` +
		`table_name, ` +
		`constraint_name ` +
		`ORDER BY row_num ` +
		`) AS ordinal_position, ` +
		`table_schema, ` +
		`table_name, ` +
		`column_name, ` +
		`constraint_name ` +
		`FROM ( ` +
		`SELECT ` +
		`ROW_NUMBER() OVER (ORDER BY 1) AS row_num, ` +
		`table_schema, ` +
		`table_name, ` +
		`column_name, ` +
		`constraint_name ` +
		`FROM information_schema.constraint_column_usage ` +
		`) t ` +
		`) AS ccu ON ccu.constraint_name = tc.constraint_name ` +
		`AND ccu.table_schema = tc.table_schema ` +
		`AND ccu.ordinal_position = kcu.ordinal_position ` +
		`WHERE tc.constraint_type = 'FOREIGN KEY' ` +
		`AND tc.table_schema = $1 ` +
		`AND tc.table_name = $2`
	// run
	logf(sqlstr, schema, table)
	rows, err := db.QueryContext(ctx, sqlstr, schema, table)
	if err != nil {
		return nil, logerror(err)
	}
	defer rows.Close()
	// load results
	var res []*ForeignKey
	for rows.Next() {
		var fk ForeignKey
		// scan
		if err := rows.Scan(&fk.ForeignKeyName, &fk.ColumnName, &fk.RefTableName, &fk.RefColumnName, &fk.KeyID); err != nil {
			return nil, logerror(err)
		}
		res = append(res, &fk)
	}
	if err := rows.Err(); err != nil {
		return nil, logerror(err)
	}
	return res, nil
}

// Sqlite3TableForeignKeys runs a custom query, returning results as ForeignKey.
func Sqlite3TableForeignKeys(ctx context.Context, db DB, schema, table string) ([]*ForeignKey, error) {
	// query
	sqlstr := `/* ` + schema + ` */ ` +
		`SELECT ` +
		`id AS key_id, ` +
		`"table" AS ref_table_name, ` +
		`"from" AS column_name, ` +
		`"to" AS ref_column_name ` +
		`FROM pragma_foreign_key_list($1)`
	// run
	logf(sqlstr, table)
	rows, err := db.QueryContext(ctx, sqlstr, table)
	if err != nil {
		return nil, logerror(err)
	}
	defer rows.Close()
	// load results
	var res []*ForeignKey
	for rows.Next() {
		var fk ForeignKey
		// scan
		if err := rows.Scan(&fk.KeyID, &fk.RefTableName, &fk.ColumnName, &fk.RefColumnName); err != nil {
			return nil, logerror(err)
		}
		res = append(res, &fk)
	}
	if err := rows.Err(); err != nil {
		return nil, logerror(err)
	}
	return res, nil
}
