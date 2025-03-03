#! /usr/bin/make
#(C) Copyright 2019-2020 Hewlett Packard Enterprise Development LP
# Inspiration from https://github.com/rightscale/go-boilerplate/blob/master/Makefile

GOFMT_FILES?=$$(find . -name '*.go' | grep -v vendor)
# Stuff that needs to be installed globally (not in vendor)
DEPEND=

# Will get the branch name
SYMBOLIC_REF=$(shell if [ -n "$$CIRCLE_TAG" ] ; then echo $$CIRCLE_TAG; else git symbolic-ref HEAD | cut -d"/" -f 3; fi)
COMMIT_ID=$(shell git rev-parse --verify HEAD)
DATE=$(shell date +"%F %T")

PACKAGE := $(shell git remote get-url origin | sed -e 's|http://||' -e 's|^.*@||' -e 's|.git||' -e 's|:|/|')
VERSION_PACKAGE=$(PACKAGE)/pkg/cmd/$@
VFLAG=-X '$(VERSION_PACKAGE).name=$@' \
      -X '$(VERSION_PACKAGE).version=$(SYMBOLIC_REF)' \
      -X '$(VERSION_PACKAGE).buildDate=$(DATE)' \
      -X '$(VERSION_PACKAGE).buildSha=$(COMMIT_ID)'
TAGS=

# kelog issue: https://github.com/rjeczalik/notify/issues/108
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	TAGS=-tags kqueue
endif
TMPFILE := $(shell mktemp)

LOCALIZATION_FILES := $(shell find . -name \*.toml | grep -v vendor | grep -v ./bin)

default: all
.PHONY: default

$(NAME): $(shell find . -name \*.go)
	CGO_ENABLED=0 go build $(TAGS) -ldflags "$(VFLAG)" -o build/$@ ./cmd/$@

vendor: go.mod go.sum
	go mod download
	go mod vendor

update up: really-clean vendor
.PHONY: update up

clean:
	rm -rf gathered_logs build .vendor/pkg $(testreport_dir) $(coverage_dir)
.PHONY: clean

really-clean clean-all cleanall: clean
	rm -rf vendor
.PHONY: really-clean clean-all cleanall

procs := $(shell grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
# TODO make --debug an option

fmtcheck:
	@sh -c "'$(CURDIR)/scripts/gofmtcheck.sh'"

fmt:
	@echo "==> Fixing source code with gofmt..."
	gofmt -s -w $(GOFMT_FILES)

tools:
	GO111MODULE=on go install github.com/golangci/golangci-lint/cmd/golangci-lint

lint:
	@echo "==> Checking source code against linters..."
	golangci-lint run ./...

testreport_dir := test-reports
test:
	go test -v ./...
.PHONY: test

coverage_dir := coverage/go
coverage: vendor
	@mkdir -p $(coverage_dir)/html
	go test -coverpkg=./... -coverprofile=$(coverage_dir)/coverage.out -v $$(go list ./... | grep -v /vendor/)
	@go tool cover -html=$(coverage_dir)/coverage.out -o $(coverage_dir)/html/main.html;
	@echo "Generated $(coverage_dir)/html/main.html";
.PHONY: coverage

all: lint test
.PHONY: tools all
