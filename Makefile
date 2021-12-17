NAME := talos
REGISTRY := docker.io/
NAMESPACE := $(REGISTRY)$(NAME)
TARGET := x86_64
VERSION := "develop"
RELEASE_DIR := release/$(VERSION)
DOCKER_BUILDKIT := 1
OUT_DIR := build/
BUILD_ARGS = $(shell cat config.env | sed 's@^@--build-arg @g' | paste -s -d " ")
.DEFAULT_GOAL := all

include config.env
export

.PHONY: all
all: images/go.tar

images/base.tar: images/base
	docker build \
		--tag $(NAMESPACE)/base \
		$(BUILD_ARGS) \
		$<
	docker save $(NAMESPACE)/base -o images/base.tar

images/go.tar: images/go images/base.tar
	docker load -i images/base.tar
	docker build \
		--tag $(NAMESPACE)/go \
		--build-arg FROM=$(NAMESPACE)/base \
		$(BUILD_ARGS) \
		$<
	docker save $(NAMESPACE)/go -o images/go.tar


.PHONY: clean
clean:
	rm -rf images/*.tar

.PHONY: mrproper
mrproper:
	docker image rm -f $(IMAGE)
	rm -rf build

.PHONY: update-packages
update-packages:
	docker rm -f "$(NAME)-update-packages" || :
	docker run \
		--rm \
		--detach \
		--name "$(NAME)-update-packages" \
		--volume $(PWD)/images/base/files/etc/apt/packages-base.list:/etc/apt/packages-base.list \
		--volume $(PWD)/images/base/files/usr/local/bin:/usr/local/bin \
		debian@sha256:$(DEBIAN_IMAGE_HASH) tail -f /dev/null
	docker exec -it "$(NAME)-update-packages" update-packages
	docker cp \
		"$(NAME)-update-packages:/etc/apt/packages.list" \
		"$(PWD)/images/base/files/etc/apt/packages.list"
	docker cp \
		"$(NAME)-update-packages:/etc/apt/sources.list" \
		"$(PWD)/images/base/files/etc/apt/sources.list"
	docker cp \
		"$(NAME)-update-packages:/etc/apt/package-hashes.txt" \
		"$(PWD)/images/base/files/etc/apt/package-hashes.txt"
	docker rm -f "$(NAME)-update-packages"
