package ischema

// Code generated by xo. DO NOT EDIT.

import (
	"database/sql"
)

// Schematum represents a row from 'information_schema.schemata'.
type Schematum struct {
	CatalogName                sql.NullString `json:"catalog_name"`                  // catalog_name
	SchemaName                 sql.NullString `json:"schema_name"`                   // schema_name
	SchemaOwner                sql.NullString `json:"schema_owner"`                  // schema_owner
	DefaultCharacterSetCatalog sql.NullString `json:"default_character_set_catalog"` // default_character_set_catalog
	DefaultCharacterSetSchema  sql.NullString `json:"default_character_set_schema"`  // default_character_set_schema
	DefaultCharacterSetName    sql.NullString `json:"default_character_set_name"`    // default_character_set_name
	SQLPath                    sql.NullString `json:"sql_path"`                      // sql_path
}
