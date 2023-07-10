package errnos

//go:generate ./generate.sh && gofmt -s -w zerrors.go

import "syscall"

func Lookup(goos, goarch string) (ret map[string]syscall.Errno) {
	for _, m := range []map[string]syscall.Errno{
		Errnos[goos+"/"+goarch],
		Errnos[goos],
	} {
		for key, val := range m {
			ret[key] = val
		}
	}
	return
}
