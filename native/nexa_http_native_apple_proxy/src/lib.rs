use nexa_http_native_core::platform::{
    ProxySettings, canonicalize_bypass_rules, clean_proxy_value, normalize_proxy_url,
};

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
        bypass: canonicalize_bypass_rules(
            exceptions
                .into_iter()
                .filter_map(|value| clean_proxy_value(&value))
                .collect(),
        ),
    }
}

fn parse_entry(entry: AppleProxyEntry, default_scheme: &str) -> Option<String> {
    if !entry.enabled {
        return None;
    }

    let host = clean_proxy_value(entry.host.as_deref()?)?;
    let host_port = match entry.port.filter(|port| *port > 0) {
        Some(port) => format!("{host}:{port}"),
        None => host,
    };
    normalize_proxy_url(&host_port, default_scheme)
}
