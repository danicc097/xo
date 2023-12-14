// Code generated by 'yaegi extract os/exec'. DO NOT EDIT.

//go:build go1.21
// +build go1.21

package internal

import (
	"os/exec"
	"reflect"
)

func init() {
	Symbols["os/exec/exec"] = map[string]reflect.Value{
		// function, constant and variable definitions
		"Command":        reflect.ValueOf(exec.Command),
		"CommandContext": reflect.ValueOf(exec.CommandContext),
		"ErrDot":         reflect.ValueOf(&exec.ErrDot).Elem(),
		"ErrNotFound":    reflect.ValueOf(&exec.ErrNotFound).Elem(),
		"ErrWaitDelay":   reflect.ValueOf(&exec.ErrWaitDelay).Elem(),
		"LookPath":       reflect.ValueOf(exec.LookPath),

		// type definitions
		"Cmd":       reflect.ValueOf((*exec.Cmd)(nil)),
		"Error":     reflect.ValueOf((*exec.Error)(nil)),
		"ExitError": reflect.ValueOf((*exec.ExitError)(nil)),
	}
}
