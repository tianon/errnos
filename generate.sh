#!/usr/bin/env bash
set -Eeuo pipefail

gawk --version > /dev/null

if [ -z "${GOLANG_SYS_DIR:-}" ]; then
	GOLANG_SYS_DIR="$(mktemp -d)"
	trap "$(printf 'rm -rf %q' "$GOLANG_SYS_DIR")" EXIT

	# https://github.com/golang/sys/tags
	git clone -b v0.10.0 --single-branch https://github.com/golang/sys.git "$GOLANG_SYS_DIR"
fi

# make sure glob expands reproducibly
export LC_ALL=C

gawk '
	BEGIN {
		print "package errnos"
		print ""
		print "import \"syscall\""
		print ""
		print "// Errnos is a doubly-nested map of GOOS or GOOS/GOARCH values to valid ERRNOs and their values (scraped from golang.org/x/sys/unix)"
		print "var Errnos = map[string]map[string]syscall.Errno{"
	}

	FNR == 1 {
		if (open) { printf "\t},\n"; open = 0 }
		if (match(FILENAME, /zerrors_([a-z0-9]+)(_([a-z0-9]+))?[.]go$/, a)) {
			if (a[3] != "") {
				a[1] = a[1] "/" a[3]
			}
			printf "\t\"%s\": {\n", a[1]
			open = 1
		}
		else {
			printf "warning: skipping %s\n", FILENAME > "/dev/stderr"
			nextfile
		}
	}

	# match lines like "EXXX = syscall.Errno(0xNN)" or "EXXX = Errno(NN)" (Errno in the sys/unix package is an alias for syscall.Errno)
	match($0, /[[:space:]](E[A-Z0-9]+)[[:space:]]*=[[:space:]]*((syscall[.])?Errno[(](0x)?[0-9a-f]+[)])([[:space:]]|$)/, a) {
		if (a[3] == "") { a[2] = "syscall." a[2] }
		printf "\t\t\"%s\": %s,\n", a[1], a[2]
	}

	END {
		if (open) { printf "\t},\n"; open = 0 }
		print "}"
	}
' "$GOLANG_SYS_DIR"/unix/zerrors_*.go > zerrors.go
