//! Parsers for Linux /proc data. Kept pure (take &str, return values) so they
//! are unit-testable on any host and under QEMU on every target arch.

#[derive(Debug, Default, Clone, PartialEq)]
pub struct MemInfo {
    pub total_kb: u64,
    pub available_kb: u64,
}

impl MemInfo {
    pub fn used_percent(&self) -> f64 {
        if self.total_kb == 0 {
            return 0.0;
        }
        let used = self.total_kb.saturating_sub(self.available_kb);
        (used as f64 / self.total_kb as f64) * 100.0
    }
}

pub fn parse_meminfo(text: &str) -> MemInfo {
    let mut m = MemInfo::default();
    for line in text.lines() {
        let mut parts = line.split_whitespace();
        let key = parts.next().unwrap_or("");
        let val: u64 = parts.next().and_then(|v| v.parse().ok()).unwrap_or(0);
        match key {
            "MemTotal:" => m.total_kb = val,
            "MemAvailable:" => m.available_kb = val,
            _ => {}
        }
    }
    m
}

#[derive(Debug, Default, Clone, PartialEq)]
pub struct LoadAvg {
    pub one: f64,
    pub five: f64,
    pub fifteen: f64,
}

pub fn parse_loadavg(text: &str) -> LoadAvg {
    let v: Vec<f64> = text
        .split_whitespace()
        .take(3)
        .filter_map(|s| s.parse().ok())
        .collect();
    LoadAvg {
        one: *v.first().unwrap_or(&0.0),
        five: *v.get(1).unwrap_or(&0.0),
        fifteen: *v.get(2).unwrap_or(&0.0),
    }
}

pub fn parse_uptime_secs(text: &str) -> u64 {
    text.split_whitespace()
        .next()
        .and_then(|s| s.parse::<f64>().ok())
        .map(|f| f as u64)
        .unwrap_or(0)
}

/// Simple health rule an OTA/lifecycle agent could act on.
pub fn health_status(mem: &MemInfo, load: &LoadAvg, cpus: usize) -> &'static str {
    let cpus = cpus.max(1) as f64;
    if mem.used_percent() > 95.0 || load.one > cpus * 4.0 {
        "critical"
    } else if mem.used_percent() > 85.0 || load.one > cpus * 2.0 {
        "degraded"
    } else {
        "healthy"
    }
}

/// Minimal JSON string escaping (no external crates).
pub fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const MEMINFO: &str =
        "MemTotal:        2048000 kB\nMemFree:          100000 kB\nMemAvailable:    1024000 kB\n";

    #[test]
    fn meminfo_parses() {
        let m = parse_meminfo(MEMINFO);
        assert_eq!(m.total_kb, 2_048_000);
        assert_eq!(m.available_kb, 1_024_000);
        assert!((m.used_percent() - 50.0).abs() < 1e-9);
    }

    #[test]
    fn meminfo_empty_is_safe() {
        assert_eq!(parse_meminfo("").used_percent(), 0.0);
    }

    #[test]
    fn loadavg_parses() {
        let l = parse_loadavg("0.52 0.41 0.30 1/123 4567\n");
        assert_eq!(
            l,
            LoadAvg {
                one: 0.52,
                five: 0.41,
                fifteen: 0.30
            }
        );
    }

    #[test]
    fn uptime_parses() {
        assert_eq!(parse_uptime_secs("12345.67 23456.78\n"), 12345);
        assert_eq!(parse_uptime_secs("garbage"), 0);
    }

    #[test]
    fn health_rules() {
        let ok = MemInfo {
            total_kb: 100,
            available_kb: 50,
        };
        let full = MemInfo {
            total_kb: 100,
            available_kb: 2,
        };
        let idle = LoadAvg {
            one: 0.1,
            ..Default::default()
        };
        let busy = LoadAvg {
            one: 9.0,
            ..Default::default()
        };
        assert_eq!(health_status(&ok, &idle, 2), "healthy");
        assert_eq!(health_status(&full, &idle, 2), "critical");
        assert_eq!(health_status(&ok, &busy, 2), "critical");
        assert_eq!(
            health_status(
                &ok,
                &LoadAvg {
                    one: 5.0,
                    ..Default::default()
                },
                2
            ),
            "degraded"
        );
    }

    #[test]
    fn escapes_json() {
        assert_eq!(json_escape("a\"b\\c\n"), "a\\\"b\\\\c\\n");
    }
}
