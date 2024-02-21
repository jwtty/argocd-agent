DOCKER_BIN?=docker

# Image names
IMAGE_REPOSITORY=quay.io/jannfis
IMAGE_NAME_AGENT=argocd-agent-agent
IMAGE_NAME_PRINCIPAL=argocd-agent-principal
IMAGE_TAG?=latest

# Binary names
BIN_NAME_AGENT=argocd-agent-agent
BIN_NAME_PRINCIPAL=argocd-agent-principal
BIN_ARCH?=$(shell go env GOARCH)
BIN_OS?=$(shell go env GOOS)

.PHONY: build
build: agent principal

.PHONY: test
test:
	mkdir -p test/out
	./hack/test.sh

.PHONY: mod-vendor
mod-vendor:
	go mod vendor

.PHONY: clean
clean:
	rm -rf dist/ vendor/ build/

./build/bin/protoc-gen-go:
	./hack/install/install-codegen-go-tools.sh

./build/bin/protoc-gen-go-grpc:
	./hack/install/install-codegen-go-tools.sh

./build/bin/protoc:
	./hack/install/install-protoc.sh

.PHONY: install-protoc-go
install-protoc-go: ./build/bin/protoc-gen-go ./build/bin/protoc-gen-go-grpc

.PHONY: install-protoc
install-protoc: ./build/bin/protoc

.PHONY: codegen
codegen: protogen

.PHONY: protogen
protogen: mod-vendor install-protoc-go install-protoc
	./hack/generate-proto.sh

.PHONY: lint
lint:
	golangci-lint run --verbose

.PHONY: agent
agent:
	CGO_ENABLED=0 GOARCH=$(BIN_ARCH) GOOS=$(BIN_OS) go build -v -o dist/$(BIN_NAME_AGENT) -ldflags="-extldflags=-static" cmd/agent/main.go

.PHONY: principal
principal:
	CGO_ENABLED=0 GOARCH=$(BIN_ARCH) GOOS=$(BIN_OS) go build -v -o dist/$(BIN_NAME_PRINCIPAL) -ldflags="-extldflags=-static" cmd/principal/main.go

.PHONY: images
images: image-agent image-principal

.PHONY: image-agent
image-agent: agent
	$(DOCKER_BIN) build -f Dockerfile.agent -t $(IMAGE_REPOSITORY)/$(IMAGE_NAME_AGENT):$(IMAGE_TAG)

.PHONY: image-principal
image-principal: principal
	$(DOCKER_BIN) build -f Dockerfile.principal -t $(IMAGE_REPOSITORY)/$(IMAGE_NAME_PRINCIPAL):$(IMAGE_TAG)
