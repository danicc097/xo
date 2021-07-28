package ischema

// Code generated by xo. DO NOT EDIT.

import (
	"database/sql"
)

// ColumnOption represents a row from 'information_schema.column_options'.
type ColumnOption struct {
	TableCatalog sql.NullString `json:"table_catalog"` // table_catalog
	TableSchema  sql.NullString `json:"table_schema"`  // table_schema
	TableName    sql.NullString `json:"table_name"`    // table_name
	ColumnName   sql.NullString `json:"column_name"`   // column_name
	OptionName   sql.NullString `json:"option_name"`   // option_name
	OptionValue  sql.NullString `json:"option_value"`  // option_value
}
