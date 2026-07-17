use reqwest::Url;
use std::collections::BTreeSet;

pub fn clean_proxy_value(value: &str) -> Option<String> {
    let cleaned = value.trim().trim_matches('"').trim_matches('\'').trim();

    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned.to_string())
    }
}

pub fn normalize_proxy_url(value: &str, default_scheme: &str) -> Option<String> {
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

pub fn split_bypass_rules(value: &str) -> Vec<String> {
    value
        .split([',', ';', '|'])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(str::to_string)
        .collect()
}

pub fn canonicalize_bypass_rules(rules: Vec<String>) -> Vec<String> {
    let mut set = BTreeSet::<String>::new();
    for item in rules {
        let trimmed = item.trim();
        if !trimmed.is_empty() {
            set.insert(trimmed.to_ascii_lowercase());
        }
    }
    set.into_iter().collect()
}
