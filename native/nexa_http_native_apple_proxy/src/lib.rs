use nexa_http_native_core::platform::ProxySettings;
use std::collections::BTreeSet;
use url::Url;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct AppleProxyEntry {
    pub enabled: bool,
    pub host: Option<String>,
    pub port: Option<i32>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct AppleProxySettings {
    pub http: AppleProxyEntry,
    pub https: AppleProxyEntry,
    pub socks: AppleProxyEntry,
    pub exceptions: Vec<String>,
    pub exclude_simple_hostnames: bool,
}

pub fn parse_apple_proxy_settings(input: AppleProxySettings) -> ProxySettings {
    let AppleProxySettings {
        http,
        https,
        socks,
        mut exceptions,
        exclude_simple_hostnames,
    } = input;

    if exclude_simple_hostnames {
        exceptions.push("<local>".to_string());
    }

    ProxySettings {
        http: parse_entry(http, "http"),
        https: parse_entry(https, "http"),
        all: parse_entry(socks, "socks5"),
        bypass: canonicalize_bypass(exceptions),
    }
}

fn canonicalize_bypass(exceptions: Vec<String>) -> Vec<String> {
    exceptions
        .into_iter()
        .filter_map(clean_value)
        .map(|value| value.to_ascii_lowercase())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn parse_entry(entry: AppleProxyEntry, default_scheme: &str) -> Option<String> {
    if !entry.enabled {
        return None;
    }

    let host = clean_value(entry.host?)?;
    let host_port = match entry.port.filter(|port| *port > 0) {
        Some(port) => format!("{host}:{port}"),
        None => host,
    };
    normalize_proxy_url(&host_port, default_scheme)
}

fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String> {
    let candidate = if value.contains("://") {
        value.to_string()
    } else {
        format!("{default_scheme}://{value}")
    };

    let parsed = Url::parse(&candidate).ok()?;
    match parsed.scheme() {
        "http" | "https" | "socks4" | "socks4a" | "socks5" | "socks5h" => Some(parsed.to_string()),
        _ => None,
    }
}

fn clean_value(value: String) -> Option<String> {
    let cleaned = value
        .trim()
        .trim_matches('"')
        .trim_matches('\'')
        .trim()
        .to_string();
    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
}
