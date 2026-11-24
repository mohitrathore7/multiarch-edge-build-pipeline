# Local entry points; each target runs the same script the CI job runs.
TARGETS := x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu armv7-unknown-linux-gnueabihf
RUNS    ?= 10

.PHONY: all lint test build verify smoke repro sbom sign images boot ci-image clean

all: lint test build verify smoke

lint:
	cargo fmt --all -- --check
	cargo clippy --locked --all-targets -- -D warnings
	shellcheck -x scripts/*.sh packaging/edgeprobe.init

test:
	cargo test --locked

build:   ; @for t in $(TARGETS); do scripts/build.sh $$t || exit 1; done
verify:  ; @for t in $(TARGETS); do scripts/verify.sh $$t || exit 1; done
smoke:   ; @for t in $(TARGETS); do scripts/qemu-user-smoke.sh $$t || exit 1; done
repro:   ; @for t in $(TARGETS); do scripts/repro-check.sh $$t $(RUNS) || exit 1; done
sbom:    ; @for t in $(TARGETS); do scripts/sbom.sh $$t || exit 1; done
sign:    ; @for t in $(TARGETS); do scripts/sign.sh $$t || exit 1; done
images:  ; @for t in $(TARGETS); do scripts/buildroot-image.sh $$t || exit 1; done
boot:    ; @for t in $(TARGETS); do scripts/qemu-boot-test.sh $$t || exit 1; done

# Run everything inside the same builder image CI uses.
ci-image:
	docker build -t edgeprobe-builder ci/
ci-local: ci-image
	docker run --rm -v $(CURDIR):/build -w /build edgeprobe-builder make all repro sbom

clean:
	cargo clean
	rm -rf dist br-images
