//! edgeprobe — reference Rust application for the multi-architecture
//! build pipeline. Reports device health as one JSON line, so it can be
//! smoke-tested the same way on x86_64, ARM64 and ARMv7 (native or QEMU).

mod probe;

use probe::*;
use std::fs;

const VERSION: &str = env!("CARGO_PKG_VERSION");
const TARGET: &str = env!("EDGEPROBE_TARGET");
const COMMIT: &str = env!("EDGEPROBE_COMMIT");
const SOURCE_DATE_EPOCH: &str = env!("EDGEPROBE_SOURCE_DATE_EPOCH");

fn read(path: &str) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

fn hostname() -> String {
    read("/proc/sys/kernel/hostname").trim().to_string()
}

fn kernel() -> String {
    read("/proc/sys/kernel/osrelease").trim().to_string()
}

fn cpu_count() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1)
}

fn version_json() -> String {
    format!(
        "{{\"name\":\"edgeprobe\",\"version\":\"{VERSION}\",\"target\":\"{TARGET}\",\
         \"arch\":\"{}\",\"commit\":\"{COMMIT}\",\"source_date_epoch\":{SOURCE_DATE_EPOCH}}}",
        std::env::consts::ARCH
    )
}

fn health_json() -> String {
    let mem = parse_meminfo(&read("/proc/meminfo"));
    let load = parse_loadavg(&read("/proc/loadavg"));
    let uptime = parse_uptime_secs(&read("/proc/uptime"));
    let cpus = cpu_count();
    format!(
        "{{\"status\":\"{}\",\"arch\":\"{}\",\"hostname\":\"{}\",\"kernel\":\"{}\",\
         \"cpus\":{cpus},\"uptime_s\":{uptime},\"mem_total_kb\":{},\"mem_available_kb\":{},\
         \"mem_used_pct\":{:.1},\"load1\":{:.2},\"load5\":{:.2},\"load15\":{:.2}}}",
        health_status(&mem, &load, cpus),
        std::env::consts::ARCH,
        json_escape(&hostname()),
        json_escape(&kernel()),
        mem.total_kb,
        mem.available_kb,
        mem.used_percent(),
        load.one,
        load.five,
        load.fifteen,
    )
}

fn usage() {
    eprintln!("usage: edgeprobe [--version | --health | --help]");
}

fn main() {
    let arg = std::env::args().nth(1).unwrap_or_else(|| "--health".into());
    match arg.as_str() {
        "--version" | "-V" => println!("{}", version_json()),
        "--health" => {
            let out = health_json();
            println!("{out}");
            // Non-zero exit lets QEMU boot tests and init scripts gate on health.
            if out.contains("\"status\":\"critical\"") {
                std::process::exit(2);
            }
        }
        "--help" | "-h" => usage(),
        _ => {
            usage();
            std::process::exit(64);
        }
    }
}
