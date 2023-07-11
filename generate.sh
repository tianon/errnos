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

jq -rR '
	[
		inputs
		# match lines like "EXXX = syscall.Errno(0xNN)" or "EXXX = Errno(NN)" (Errno in the sys/unix package is an alias for syscall.Errno)
		| capture("[[:space:]](?<name>E[A-Z0-9]+)[[:space:]]*=[[:space:]]*((syscall[.])?Errno[(](?<value>(0x)?[0-9a-f]+)[)])([[:space:]]|$)")
		# upgrade to include goos and goarch from the filename
		| . += (input_filename | capture("zerrors_(?<goos>[a-z0-9]+)(_(?<goarch>[a-z0-9]+))?[.]go$"))
	]
	| (reduce .[] as $o ({}; select($o.goarch) | .[$o.goos] += [$o.goarch])) as $arches
	| reduce .[] as $o ({}; .[$o.goos][$o.goarch // $arches[$o.goos][]][$o.name] = $o.value)
	| [
		"package errnos",
		"",
		"import \"syscall\"",
		"",
		"// Errnos is a triply-nested map of GOOS -> GOARCH -> ERRNO define -> ERRNO values (scraped from golang.org/x/sys/unix)",
		"var Errnos = map[string]map[string]map[string]syscall.Errno{",
		(
			to_entries[] |
			"\t\"" + .key + "\": {", # GOOS
			(
				.value | to_entries[] |
				"\t\t\"" + .key + "\": {", # GOARCH
				(
					.value
					| (keys_unsorted | map(length) | max) as $longest # find the longest key so we can gofmt properly
					| to_entries[]
					| "\t\t\t\"" + .key + "\": " + (" " * ($longest - (.key | length))) + "syscall.Errno(" + .value + "),"
				),
				"\t\t},",
				empty
			),
			"\t},",
			empty
		),
		"}",
		empty
	] | join("\n")
' "$GOLANG_SYS_DIR"/unix/zerrors_*.go > zerrors.go
