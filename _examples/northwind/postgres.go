package main

import (
	"context"
	"database/sql"
	"fmt"

	models "github.com/danicc097/xo/v5/_examples/northwind/postgres"
)

func runPostgres(ctx context.Context, db *sql.DB) error {
	p, err := models.ProductByProductID(ctx, db, 16)
	if err != nil {
		return err
	}
	fmt.Printf("product %d: %q\n", p.ProductID, p.ProductName)
	return nil
}
