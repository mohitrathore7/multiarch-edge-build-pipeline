# Builder image used by every job in .gitlab-ci.yml.
# Pinned base + pinned Rust toolchain = same compiler on every runner,
# which is a precondition for bit-for-bit reproducible builds.
FROM ubuntu:24.04

ARG RUST_TOOLCHAIN=1.80.1
ARG COSIGN_VERSION=2.4.1
ARG CYCLONEDX_VERSION=0.5.7

ENV DEBIAN_FRONTEND=noninteractive \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH \
    LC_ALL=C.UTF-8 TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq file binutils xz-utils shellcheck \
      build-essential pkg-config \
      gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
      gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
      qemu-user qemu-system-arm qemu-system-x86 \
      bc bzip2 cpio rsync unzip wget patch perl python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal \
      --default-toolchain "$RUST_TOOLCHAIN" \
      --component rustfmt,clippy \
      --target aarch64-unknown-linux-gnu \
      --target armv7-unknown-linux-gnueabihf \
    && cargo install cargo-cyclonedx --version "$CYCLONEDX_VERSION" --locked \
    && rm -rf "$CARGO_HOME/registry" "$CARGO_HOME/git"

RUN curl -fsSL -o /usr/local/bin/cosign \
      "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64" \
    && chmod +x /usr/local/bin/cosign

# Buildroot refuses to run as root unless forced; CI runs as root in containers.
ENV FORCE_UNSAFE_CONFIGURE=1

WORKDIR /build
