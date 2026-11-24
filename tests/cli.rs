//! Black-box tests of the built binary. Run on the host target; cross targets
//! are covered by unit tests under QEMU (`cargo test --target <t> --bins`)
//! and by scripts/qemu-user-smoke.sh.

use std::process::Command;

fn edgeprobe(arg: &str) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_edgeprobe"))
        .arg(arg)
        .output()
        .expect("failed to run edgeprobe")
}

#[test]
fn version_reports_target_and_arch() {
    let out = edgeprobe("--version");
    assert!(out.status.success());
    let s = String::from_utf8(out.stdout).unwrap();
    assert!(
        s.starts_with('{') && s.trim_end().ends_with('}'),
        "not JSON: {s}"
    );
    assert!(s.contains("\"name\":\"edgeprobe\""));
    assert!(s.contains(&format!("\"arch\":\"{}\"", std::env::consts::ARCH)));
    assert!(s.contains("\"target\":\""));
    assert!(s.contains("\"source_date_epoch\":"));
}

#[test]
fn health_reports_status() {
    let out = edgeprobe("--health");
    let s = String::from_utf8(out.stdout).unwrap();
    assert!(
        s.contains("\"status\":\"healthy\"")
            || s.contains("\"status\":\"degraded\"")
            || s.contains("\"status\":\"critical\""),
        "{s}"
    );
    assert!(s.contains("\"mem_total_kb\":"));
    // exit code mirrors status: 2 only for critical
    let critical = s.contains("\"status\":\"critical\"");
    assert_eq!(out.status.code(), Some(if critical { 2 } else { 0 }));
}

#[test]
fn unknown_flag_exits_64() {
    let out = edgeprobe("--bogus");
    assert_eq!(out.status.code(), Some(64));
}
