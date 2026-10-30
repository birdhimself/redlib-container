# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# supported versions here: https://hub.docker.com/_/rust
FROM rust:1.99.1-alpine@sha256:7e9e2d068a107a2adafd19930011178d14a78326053cd4c3a9f7ad3fd049557d AS builder

# renovate: packageName=https://github.com/redlib-org/redlib branch=main
ARG REDLIB_REF=ba116c1186f6b0f9d45f0ae50c827e13eb2f5ea2
ARG REDLIB_SRC=https://github.com/redlib-org/redlib.git

# git: build.rs stamps the commit hash; cmake/g++/perl/clang: BoringSSL (wreq)
RUN apk add --no-cache git make cmake perl musl-dev g++ clang-dev linux-headers

WORKDIR /redlib

RUN git init -q . \
    && git fetch -q --depth 1 "${REDLIB_SRC}" "${REDLIB_REF}" \
    && git checkout -q FETCH_HEAD
# static build scripts can't dlopen libclang (bindgen), so link dynamically
ENV RUSTFLAGS="-C target-feature=-crt-static"
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo build --release --locked --bin redlib

FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS release

RUN apk add --no-cache ca-certificates libgcc libstdc++

COPY --from=builder /redlib/target/release/redlib /usr/local/bin/redlib

RUN adduser --home /nonexistent --no-create-home --disabled-password redlib
USER redlib

EXPOSE 8080

HEALTHCHECK --interval=1m --timeout=3s CMD wget --spider -q http://localhost:8080/settings || exit 1

CMD ["redlib"]
