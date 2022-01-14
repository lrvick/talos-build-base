ARG DEBIAN_IMAGE_HASH

FROM debian@sha256:${DEBIAN_IMAGE_HASH} AS build

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=UTC \
    HOME=/home/build \
    PATH=/home/build/.local/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ADD files /

RUN apt-install

RUN enable-faketime

RUN useradd -ms /bin/bash build
USER build
WORKDIR /home/build
RUN mkdir -p /home/build/.local/bin

FROM base AS base

## Fetch/Verify Sources
ARG VERSION=1.16
ARG HASH=7688063d55656105898f323d90a79a39c378d86fe89ae192eb3b7fc46347c95a
ARG URL=https://storage.googleapis.com/golang/go1.16.src.tar.gz
ARG KEY=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796

RUN set -eux; \
    curl -o go.tgz.asc ${URL}.asc; \
    curl -o go.tgz ${URL}; \
    echo "${HASH} *go.tgz" | sha256sum --strict --check -; \
    export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${KEY}; \
	gpg --batch --verify go.tgz.asc go.tgz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" go.tgz.asc; \
	tar -C .local -xzf go.tgz; \
	rm go.tgz;

# Build
RUN ( cd .local/go/src && ./make.bash; ); \
    go install -race std; \
    rm -rf \
		/usr/local/go/pkg/*/cmd \
		/usr/local/go/pkg/bootstrap \
		/usr/local/go/pkg/obj \
		/usr/local/go/pkg/tool/*/api \
		/usr/local/go/pkg/tool/*/go_bootstrap \
		/usr/local/go/src/cmd/dist/dist \
	; \
    mv .local/go/bin/* .local/bin/; \
    go version

ENV GOBIN=/home/build/src/bin \
    GOPATH=/home/build/src/go \
    CGO_ENABLED=0 \
    GOOS=linux \
    GO11MODULE=on \
    GOPROXY=direct

WORKDIR /src
ENTRYPOINT ["/usr/local/bin/host-env"]
CMD ["/usr/local/bin/build"]
