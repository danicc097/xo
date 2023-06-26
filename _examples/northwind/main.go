// Command northwind demonstrates using generated models for the northwind
// sample database.
//
// Schema/data comes from the Yugabyte Database Git repository. See README.md
// for more information.
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"os"
	"os/user"

	// drivers
	_ "github.com/lib/pq"
	_ "github.com/mattn/go-sqlite3"

	// models
	"github.com/danicc097/xo/v5/_examples/northwind/postgres"
	"github.com/danicc097/xo/v5/_examples/northwind/sqlite3"

	"github.com/xo/dburl"
	"github.com/xo/dburl/passfile"
)

func main() {
	verbose := flag.Bool("v", false, "verbose")
	dsn := flag.String("dsn", "", "dsn")
	flag.Parse()
	if err := run(context.Background(), *verbose, *dsn); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, verbose bool, dsn string) error {
	if verbose {
		logger := func(s string, v ...interface{}) {
			fmt.Printf("-------------------------------------\nQUERY: %s\n  VAL: %v\n\n", s, v)
		}
		postgres.SetLogger(logger)
		sqlite3.SetLogger(logger)
	}
	v, err := user.Current()
	if err != nil {
		return err
	}
	// parse url
	u, err := parse(dsn)
	if err != nil {
		return err
	}
	// open database
	db, err := passfile.OpenURL(u, v.HomeDir, "xopass")
	if err != nil {
		return err
	}
	var f func(context.Context, *sql.DB) error
	switch u.Driver {
	case "postgres":
		f = runPostgres
	case "sqlite3":
		f = runSqlite3
	}
	return f(ctx, db)
}

func parse(dsn string) (*dburl.URL, error) {
	v, err := dburl.Parse(dsn)
	if err != nil {
		return nil, err
	}
	switch v.Driver {
	case "sqlite3":
		q := v.Query()
		q.Set("_loc", "auto")
		v.RawQuery = q.Encode()
		return dburl.Parse(v.String())
	}
	return v, nil
}
