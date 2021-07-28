package ischema

// Code generated by xo. DO NOT EDIT.

import (
	"database/sql"
)

// ForeignTable represents a row from 'information_schema.foreign_tables'.
type ForeignTable struct {
	ForeignTableCatalog  sql.NullString `json:"foreign_table_catalog"`  // foreign_table_catalog
	ForeignTableSchema   sql.NullString `json:"foreign_table_schema"`   // foreign_table_schema
	ForeignTableName     sql.NullString `json:"foreign_table_name"`     // foreign_table_name
	ForeignServerCatalog sql.NullString `json:"foreign_server_catalog"` // foreign_server_catalog
	ForeignServerName    sql.NullString `json:"foreign_server_name"`    // foreign_server_name
}
