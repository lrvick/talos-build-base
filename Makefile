REGISTRY ?= ghcr.io
USERNAME ?= talos-systems
TAG ?= $(shell git describe --tag --always --dirty)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
RUN_TESTS ?=

BUILD_PLATFORM ?= linux/amd64
PLATFORM ?= linux/amd64,linux/arm64
PROGRESS ?= auto
PUSH ?= false

BUILD := docker buildx build
COMMON_ARGS := --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --build-arg=VERSION=$(TAG)
COMMON_ARGS += --build-arg=USERNAME=$(USERNAME)
COMMON_ARGS += --build-arg=REGISTRY=$(REGISTRY)
COMMON_ARGS += $(shell cat config.env | sed 's@^@--build-arg @g' | paste -s -d " ")

include config.env
export

PKGS := build base

all: $(PKGS)

.DEFAULT_GOAL := all

.PHONY: all
all: images/go.tar

.PHONY: build
build:
	$(BUILD) $(COMMON_ARGS) \
		--target=$@ \
		.

.PHONY: base
base:
	$(BUILD) $(COMMON_ARGS) \
		--target=$@ \
		--tag $(REGISTRY_AND_USERNAME)/$@:$(TAG)-$@ \
		.

.PHONY: clean
clean:
	rm -rf images/*.tar

.PHONY: mrproper
mrproper:
	docker image rm -f $(IMAGE)
	rm -rf build

.PHONY: update-packages
update-packages:
	docker rm -f "$(USERNAME)-update-packages" || :
	docker run \
		--rm \
		--detach \
		--platform=linux/arm64 \
		--name "$(USERNAME)-update-packages-aarch64" \
		--volume $(PWD)/files/etc/apt/packages-base.list:/etc/apt/packages-base.list \
		--volume $(PWD)/files/usr/local/bin:/usr/local/bin \
		debian tail -f /dev/null
		#debian@sha256:$(DEBIAN_IMAGE_HASH) tail -f /dev/null
	docker run \
		--rm \
		--detach \
		--platform=linux/x86_64 \
		--name "$(USERNAME)-update-packages-x86_64" \
		--volume $(PWD)/files/etc/apt/packages-base.list:/etc/apt/packages-base.list \
		--volume $(PWD)/files/usr/local/bin:/usr/local/bin \
		debian tail -f /dev/null
		#debian@sha256:$(DEBIAN_IMAGE_HASH) tail -f /dev/null
	docker exec -it "$(USERNAME)-update-packages-x86_64" update-packages
	docker exec -it "$(USERNAME)-update-packages-aarch64" update-packages
	docker cp \
		"$(USERNAME)-update-packages-x86_64:/etc/apt/packages.list" \
		"$(PWD)/files/etc/apt/packages-x86_64.list"
	docker cp \
		"$(USERNAME)-update-packages-aarch64:/etc/apt/packages.list" \
		"$(PWD)/files/etc/apt/packages-aarch64.list"
	docker cp \
		"$(USERNAME)-update-packages-x86_64:/etc/apt/package-hashes.txt" \
		"$(PWD)/files/etc/apt/package-hashes-x86_64.txt"
	docker cp \
		"$(USERNAME)-update-packages-aarch64:/etc/apt/package-hashes.txt" \
		"$(PWD)/files/etc/apt/package-hashes-aarch64.txt"
	docker cp \
		"$(USERNAME)-update-packages-x86_64:/etc/apt/sources.list" \
		"$(PWD)/files/etc/apt/sources.list"
	docker rm -f "$(USERNAME)-update-packages-x86_64"
	docker rm -f "$(USERNAME)-update-packages-aarch64"
