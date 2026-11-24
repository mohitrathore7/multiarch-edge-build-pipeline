# Design notes

## Goals

1. One pipeline builds the same Rust app for x86_64, ARM64 and ARMv7.
2. Every artifact is checked before it is used: right architecture, right ABI, runs, fits on the device.
3. Same commit in = same bytes out, and the pipeline proves it on every run.
4. Every shipped artifact has an SBOM and a signature.
5. The artifact is tested inside a real embedded Linux image, not only on the build host.

## Decisions

**One matrix, many stages.** `.arch-matrix` is reused by build, verify, reproducibility, SBOM, sign, image and boot-test. Downstream matrix jobs use `needs: [build]`, which pulls the artifacts of all build instances. Each arch writes to its own `dist/<arch>/`, so they never collide and each job picks its own by `$ARCH`.

**Scripts, not YAML logic.** Each CI job calls one script in `scripts/`. The same scripts run locally (`make ...`), so a failing job can be reproduced on a laptop with one command. Shared mapping (triple → arch name → QEMU runner) lives only in `scripts/common.sh`.

**Two QEMU levels.**
- *User-mode* (`qemu-aarch64`, `qemu-arm`): fast, runs on every pipeline. Used for cross unit tests (cargo `runner` in `.cargo/config.toml`) and smoke tests.
- *System-mode* (`qemu-system-*`): boots a full kernel + rootfs. Slower, runs on main/tags/schedules and on demand in MRs. Catches things user-mode can't: missing loader or libc on the rootfs, init integration, kernel compatibility.

**Buildroot ships the verified bytes; Yocto rebuilds from source.** Buildroot installs `dist/<arch>/edgeprobe` after a SHA-256 check, so what boots in QEMU is exactly what was verified and signed. Yocto builds from the same commit with its own Rust toolchain. That gives a second, independent build path and a whole-image SPDX SBOM, which is how a real BSP team would consume the app.

**Zero dependencies.** No crates means a tiny SBOM, no supply-chain surface from crates.io, offline builds (Yocto needs no `crate://` fetches) and fewer reproducibility variables. JSON output is hand-written for the same reason.

**Size and glibc budgets.** Both are CI variables (`MAX_SIZE_KB`, `MAX_GLIBC`). A new dependency or toolchain bump that silently raises the glibc requirement fails `verify` instead of failing on a device in the field.

**Signing with a key, offline.** `cosign sign-blob` with a key from a GitLab File variable, no transparency-log upload, so the pipeline also works on air-gapped runners. Keyless (OIDC) signing with GitLab ID tokens is the natural next step for public projects.

## What actually matters for reproducibility (measured)

I removed each setting one at a time and rebuilt in two different directories (x86_64, same `SOURCE_DATE_EPOCH`):

| Removed | Result | Why |
|---|---|---|
| `--remap-path-prefix` | still identical | No dependencies and a stripped release binary: the only paths left are relative (`src/main.rs`). Absolute paths appear once a crate from `~/.cargo/registry` is added (panic locations) or debug info is kept. |
| `-Wl,--build-id=none` | still identical | The GNU build-id is a hash of the linked content, so it is deterministic when the input is. |
| fixed `SOURCE_DATE_EPOCH` | **differs** | `build.rs` embeds it in `--version`. |
| same commit | **differs** across commits | the commit hash is embedded on purpose. |

So the two flags are guards, not fixes: they cost nothing and keep the build reproducible when dependencies are added. The real safety net is `repro-check.sh` building in a different directory every run, plus `verify.sh` failing on any leaked absolute path, so a regression shows up in the MR that causes it.

The SBOM needed the same treatment: its timestamp is set from `SOURCE_DATE_EPOCH` and any `serialNumber` (random UUID in some cargo-cyclonedx versions) is removed, so the SBOM is reproducible too.

## Not covered (yet)

- Real hardware runners (e.g. a Jetson or Raspberry Pi as a GitLab runner with a `hw-test` stage).
- musl/static builds as an alternative to the glibc floor.
- OCI packaging of the artifact (e.g. `oras push` with the SBOM and signature attached).
- Keyless signing and SLSA provenance attestations.
