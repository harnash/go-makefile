SOURCEDIR := .
SOURCES := $(shell find $(SOURCEDIR) -name '*.go')
# Go utilities
GO_LINT := ${GOPATH}/bin/golint
GO_GODEP := ${GOPATH}/bin/godep
GO_BINDATA := ${GOPATH}/bin/bindata

# Handling project dirs and names
ROOT_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
PROJECT_PATH := $(subst $(GOPATH)/src/,, $(ROOT_DIR))
PROJECT_NAME := $(lastword $(subst /, , $(PROJECT_PATH)))
# For some reason $(patsubst %/,, ) doesn't work on OSX
PROJECT_PATH := $(subst $(PROJECT_NAME)/,$(PROJECT_NAME), $(PROJECT_PATH))
PROJECT_PATH := $(strip $(PROJECT_PATH))

BINARY := bin/$(PROJECT_NAME)

TARGETS := $(shell go list ./... | grep -v ^$(PROJECT_PATH)/vendor | sed 's!$(PROJECT_PATH)/!!' | grep -v $(PROJECT_PATH))
TARGETS_TEST := $(patsubst %,test-%, $(TARGETS))
TARGETS_LINT := $(patsubst %,lint-%, $(TARGETS))
TARGETS_VET  := $(patsubst %,vet-%, $(TARGETS))
TARGETS_FMT  := $(patsubst %,fmt-%, $(TARGETS))

# Injecting project version and build time
VERSION_GIT := $(shell sh -c 'git describe --always --tags')
BUILD_TIME := `date +%FT%T%z`
VERSION_PACKAGE := $(PROJECT_PATH)/main
LDFLAGS := -ldflags "-X $(VERSION_PACKAGE).Version=${VERSION_GIT} -X $(VERSION_PACKAGE).BuildTime=${BUILD_TIME}"

.DEFAULT_GOAL: $(BINARY)

$(BINARY): $(SOURCES) prepare
	go build ${LDFLAGS} -o ${BINARY} main.go

$(GO_LINT):
	go get -u github.com/golang/lint/golint

$(GO_GODEP):
	go get -u github.com/tools/godep

prepare: $(GO_GODEP)
	$(GO_GODEP) restore

install:
	go install ${LDFLAGS} ./...

test: vet $(TARGETS_TEST)
# @go test

$(TARGETS_TEST): test-%: %
	@go test ./$<

vet: $(TARGETS_VET)
# @go vet

$(TARGETS_VET): vet-%: %
	@go vet $</*.go

fmt: $(TARGETS_FMT)
# @go fmt

$(TARGETS_FMT): fmt-%: %
	@go fmt $</*.go

lint: $(GO_LINT) $(TARGETS_LINT)
# @golint

$(TARGETS_LINT): lint-%: %
	@$(GO_LINT) $<

$(GO_BINDATA):
	go get -u github.com/jteeuwen/go-bindata/...

gen-resources: $(GO_BINDATA)
	$(GO_BINDATA) -o resources/resources.go -pkg resources -prefix resources -ignore resources.go resources/...

clean:
	if [ -f ${BINARY} ] ; then rm ${BINARY} ; fi

.PHONY: test lint vet $(TARGETS_TEST) $(TARGETS_LINT)