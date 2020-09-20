APP := miniflux
DOCKER_IMAGE := docker.pkg.github.com/sassospicco/miniflux/miniflux
VERSION := $(shell git rev-parse --short HEAD)
BUILD_DATE := `date +%FT%T%z`
LD_FLAGS := "-s -w -X 'miniflux.app/version.Version=$(VERSION)' -X 'miniflux.app/version.BuildDate=$(BUILD_DATE)'"
PKG_LIST := $(shell go list ./... | grep -v /vendor/)
DB_URL := postgres://postgres:postgres@localhost/miniflux_test?sslmode=disable

export PGPASSWORD := postgres
export GO111MODULE=on

.PHONY: generate \
	miniflux \
	linux-amd64 \
	linux-armv8 \
	linux-armv7 \
	linux-armv6 \
	linux-armv5 \
	linux-x86 \
	darwin-amd64 \
	freebsd-amd64 \
	freebsd-x86 \
	openbsd-amd64 \
	openbsd-x86 \
	netbsd-x86 \
	netbsd-amd64 \
	windows-amd64 \
	windows-x86 \
	build \
	run \
	clean \
	test \
	lint \
	integration-test \
	clean-integration-test \
	docker-image \
	docker-images \
	docker-manifest

generate:
	go generate -mod=vendor

miniflux: generate
	go build -ldflags=$(LD_FLAGS) -o $(APP) main.go

linux-amd64: generate
	GOOS=linux GOARCH=amd64 go build -ldflags=$(LD_FLAGS) -o $(APP)-linux-amd64 main.go

build: linux-amd64

run: generate
	go run main.go -debug

clean:
	rm -f $(APP)-* $(APP)

test:
	go test -cover -race -count=1 ./...

lint:
	golint -set_exit_status ${PKG_LIST}

integration-test:
	psql -U postgres -c 'drop database if exists miniflux_test;'
	psql -U postgres -c 'create database miniflux_test;'
	DATABASE_URL=$(DB_URL) go run main.go -migrate
	DATABASE_URL=$(DB_URL) ADMIN_USERNAME=admin ADMIN_PASSWORD=test123 go run main.go -create-admin
	go build -o miniflux-test main.go
	DATABASE_URL=$(DB_URL) ./miniflux-test -debug >/tmp/miniflux.log 2>&1 & echo "$$!" > "/tmp/miniflux.pid"
	while ! echo exit | nc localhost 8080; do sleep 1; done >/dev/null
	go test -v -tags=integration -count=1 miniflux.app/tests

clean-integration-test:
	kill -9 `cat /tmp/miniflux.pid`
	rm -f /tmp/miniflux.pid /tmp/miniflux.log
	rm miniflux-test
	psql -U postgres -c 'drop database if exists miniflux_test;'

docker-image:
	docker build -t $(DOCKER_IMAGE):$(VERSION) \
		--build-arg APP_VERSION=$(VERSION) \
		--build-arg APP_ARCH=amd64 \
		--build-arg BASE_IMAGE_ARCH=amd64 .
