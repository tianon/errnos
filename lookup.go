package errnos

//go:generate ./generate.sh && gofmt -s -w zerrors.go

import (
	"fmt"
	"syscall"
)

func Lookup(goos, goarch, err string) (syscall.Errno, error) {
	if errno, ok := Errnos[goos+"/"+goarch][err]; ok {
		return errno, nil
	}
	if errno, ok := Errnos[goos][err]; ok {
		return errno, nil
	}
	return syscall.Errno(0), fmt.Errorf("unknown errno for %s/%s: %s", goos, goarch, err)
}
