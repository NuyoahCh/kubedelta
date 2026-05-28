.PHONY: tools cluster-up cluster-down build test

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

tools:
	@bash $(ROOT)scripts/install-tools.sh

build:
	go build -o $(ROOT).bin/kubedelta-extender ./cmd/kubedelta-extender

test:
	go test ./...

cluster-up:
	@bash $(ROOT)scripts/cluster-up.sh

cluster-down:
	@bash $(ROOT)scripts/cluster-down.sh
