//! Embeds build metadata into the binary *without* breaking reproducibility:
//! no wall-clock time, only values that are identical for identical inputs.

use std::process::Command;

fn main() {
    let target = std::env::var("TARGET").unwrap_or_else(|_| "unknown".into());
    println!("cargo:rustc-env=EDGEPROBE_TARGET={target}");

    // Commit hash: CI provides it; fall back to git; else "unknown".
    let commit = std::env::var("CI_COMMIT_SHORT_SHA")
        .or_else(|_| std::env::var("GITHUB_SHA").map(|s| s.chars().take(8).collect()))
        .ok()
        .or_else(|| {
            Command::new("git")
                .args(["rev-parse", "--short=8", "HEAD"])
                .output()
                .ok()
                .filter(|o| o.status.success())
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        })
        .unwrap_or_else(|| "unknown".into());
    println!("cargo:rustc-env=EDGEPROBE_COMMIT={commit}");

    // SOURCE_DATE_EPOCH (reproducible-builds.org) instead of "now".
    let epoch = std::env::var("SOURCE_DATE_EPOCH").unwrap_or_else(|_| "0".into());
    println!("cargo:rustc-env=EDGEPROBE_SOURCE_DATE_EPOCH={epoch}");

    println!("cargo:rerun-if-env-changed=CI_COMMIT_SHORT_SHA");
    println!("cargo:rerun-if-env-changed=GITHUB_SHA");
    println!("cargo:rerun-if-env-changed=SOURCE_DATE_EPOCH");
}
