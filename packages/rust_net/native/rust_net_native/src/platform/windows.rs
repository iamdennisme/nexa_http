use crate::platform::{PlatformFeatures, ProxySettings};
use reqwest::Url;
use std::collections::BTreeSet;

#[cfg(target_os = "windows")]
use winreg::{RegKey, enums};

pub(crate) fn current() -> PlatformFeatures {
    PlatformFeatures {
        proxy: current_proxy_settings(),
    }
}

fn current_proxy_settings() -> ProxySettings {
    #[cfg(target_os = "windows")]
    {
        registry::current_proxy_settings()
    }

    #[cfg(not(target_os = "windows"))]
    {
        ProxySettings::default()
    }
}

fn proxy_settings_from_proxy_server(server: &str, bypass: Option<&str>) -> ProxySettings {
    let server = server.trim();
    if server.is_empty() {
        return ProxySettings::default();
    }

    let mut settings = ProxySettings::default();

    if server.contains('=') {
        for entry in server
            .split(';')
            .map(str::trim)
            .filter(|entry| !entry.is_empty())
        {
            let Some((scheme, address)) = entry.split_once('=') else {
                continue;
            };
            let scheme_lower = scheme.trim().to_ascii_lowercase();
            let address = address.trim();

            match scheme_lower.as_str() {
                "http" => settings.http = normalize_proxy_url(address, "http"),
                "https" => settings.https = normalize_proxy_url(address, "http"),
                // Windows often uses `socks=` even though the underlying scheme is socks5.
                "socks" | "socks4" | "socks4a" | "socks5" | "socks5h" => {
                    let default_scheme = if scheme_lower == "socks" {
                        "socks5"
                    } else {
                        scheme_lower.as_str()
                    };
                    settings.all = normalize_proxy_url(address, default_scheme);
                }
                _ => {}
            }
        }
    } else {
        let normalized = normalize_proxy_url(server, "http");
        settings.http = normalized.clone();
        settings.https = normalized;
    }

    settings.bypass = bypass
        .map(parse_bypass_list)
        .unwrap_or_default();
    dedup_bypass(&mut settings);
    settings
}

fn parse_bypass_list(value: &str) -> Vec<String> {
    value
        .split([',', ';', '|'])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(|item| item.to_string())
        .collect()
}

fn dedup_bypass(settings: &mut ProxySettings) {
    let mut set = BTreeSet::<String>::new();
    for item in &settings.bypass {
        let trimmed = item.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_ascii_lowercase());
        }
    }
    settings.bypass = set.into_iter().collect();
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

#[cfg(target_os = "windows")]
mod registry {
    use super::*;

    pub(super) fn current_proxy_settings() -> ProxySettings {
        const SUB_KEY: &str = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";

        let hkcu = RegKey::predef(enums::HKEY_CURRENT_USER);
        let key = match hkcu.open_subkey_with_flags(SUB_KEY, enums::KEY_READ) {
            Ok(key) => key,
            Err(_) => return ProxySettings::default(),
        };

        if key.get_value::<u32, _>("ProxyEnable").ok() != Some(1) {
            return ProxySettings::default();
        }

        let server = match key.get_value::<String, _>("ProxyServer") {
            Ok(value) => value,
            Err(_) => return ProxySettings::default(),
        };
        let bypass = key.get_value::<String, _>("ProxyOverride").ok();

        proxy_settings_from_proxy_server(&server, bypass.as_deref())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn windows_parses_split_proxy_server_entries() {
        let settings = proxy_settings_from_proxy_server(
            "http=127.0.0.1:8080;https=127.0.0.1:8443;socks=127.0.0.1:1080",
            Some("localhost;127.0.0.1;*.example.com"),
        );

        assert_eq!(settings.http.as_deref(), Some("http://127.0.0.1:8080/"));
        assert_eq!(settings.https.as_deref(), Some("http://127.0.0.1:8443/"));
        assert_eq!(settings.all.as_deref(), Some("socks5://127.0.0.1:1080"));
        assert!(settings.bypass.contains(&"localhost".to_string()));
        assert!(settings.bypass.contains(&"127.0.0.1".to_string()));
        assert!(settings.bypass.contains(&"*.example.com".to_string()));
    }

    #[test]
    fn windows_single_proxy_server_applies_to_http_and_https() {
        let settings = proxy_settings_from_proxy_server("127.0.0.1:8888", None);
        assert_eq!(settings.http.as_deref(), Some("http://127.0.0.1:8888/"));
        assert_eq!(settings.https.as_deref(), Some("http://127.0.0.1:8888/"));
        assert_eq!(settings.all.as_deref(), None);
    }

    #[test]
    fn windows_ignores_unknown_schemes_in_split_entries() {
        let settings = proxy_settings_from_proxy_server(
            "ftp=127.0.0.1:21;http=127.0.0.1:8080",
            None,
        );
        assert_eq!(settings.http.as_deref(), Some("http://127.0.0.1:8080/"));
        assert_eq!(settings.https.as_deref(), None);
        assert_eq!(settings.all.as_deref(), None);
    }
}
