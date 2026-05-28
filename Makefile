.PHONY: tools cluster-up cluster-down build test verify scale-node

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

export PATH := $(ROOT).bin:$(PATH)

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

verify:
	@bash $(ROOT)scripts/verify-cluster.sh

scale-node:
	@bash $(ROOT)scripts/simulate-lamby-scale.sh $(POOL)
