// Command booktest is an example of using a similar schema on different
// databases.
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

	// models
	"github.com/danicc097/xo/v5/_examples/booktest/postgres"

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
	}
	return f(ctx, db)
}

func parse(dsn string) (*dburl.URL, error) {
	v, err := dburl.Parse(dsn)
	if err != nil {
		return nil, err
	}
	return v, nil
}
