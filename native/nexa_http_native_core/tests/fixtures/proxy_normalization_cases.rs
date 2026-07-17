#![allow(dead_code)]

#[derive(Clone, Copy, Debug)]
pub struct CleanupCase {
    pub input: &'static str,
    pub expected: Option<&'static str>,
}

pub const CLEANUP_CASES: &[CleanupCase] = &[
    CleanupCase {
        input: " proxy.example.com ",
        expected: Some("proxy.example.com"),
    },
    CleanupCase {
        input: r#" "proxy.example.com" "#,
        expected: Some("proxy.example.com"),
    },
    CleanupCase {
        input: "'proxy.example.com'",
        expected: Some("proxy.example.com"),
    },
    CleanupCase {
        input: r#" " " "#,
        expected: None,
    },
    CleanupCase {
        input: "",
        expected: None,
    },
];

#[derive(Clone, Copy, Debug)]
pub struct UrlCase {
    pub input: &'static str,
    pub default_scheme: &'static str,
    pub expected: Option<&'static str>,
}

pub const URL_CASES: &[UrlCase] = &[
    UrlCase {
        input: "proxy.example.com:3128",
        default_scheme: "http",
        expected: Some("http://proxy.example.com:3128/"),
    },
    UrlCase {
        input: "proxy.example.com:8443",
        default_scheme: "https",
        expected: Some("https://proxy.example.com:8443/"),
    },
    UrlCase {
        input: "socks5://127.0.0.1:1080",
        default_scheme: "http",
        expected: Some("socks5://127.0.0.1:1080"),
    },
    UrlCase {
        input: "socks4://proxy.example.com:1080",
        default_scheme: "http",
        expected: Some("socks4://proxy.example.com:1080"),
    },
    UrlCase {
        input: "socks4a://proxy.example.com:1080",
        default_scheme: "http",
        expected: Some("socks4a://proxy.example.com:1080"),
    },
    UrlCase {
        input: "socks5h://proxy.example.com:1080",
        default_scheme: "http",
        expected: Some("socks5h://proxy.example.com:1080"),
    },
    UrlCase {
        input: "ftp://proxy.example.com:21",
        default_scheme: "http",
        expected: None,
    },
    UrlCase {
        input: "http://",
        default_scheme: "http",
        expected: None,
    },
];

#[derive(Clone, Copy, Debug)]
pub struct SplitCase {
    pub input: &'static str,
    pub expected: &'static [&'static str],
}

const SPLIT_RULES: &[&str] = &["localhost", "127.0.0.1", "*.example.com"];
const SPLIT_CASE_VARIANTS: &[&str] = &["A", "a"];

pub const SPLIT_CASES: &[SplitCase] = &[
    SplitCase {
        input: "localhost|127.0.0.1; *.example.com,,",
        expected: SPLIT_RULES,
    },
    SplitCase {
        input: " A , a ; | ",
        expected: SPLIT_CASE_VARIANTS,
    },
];

#[derive(Clone, Copy, Debug)]
pub struct CanonicalizeCase {
    pub input: &'static [&'static str],
    pub expected: &'static [&'static str],
}

const CANONICAL_INPUT: &[&str] = &[
    " Example.COM ",
    "example.com",
    "",
    "LOCALHOST",
    "\"Quoted.COM\"",
];
const CANONICAL_OUTPUT: &[&str] = &["\"quoted.com\"", "example.com", "localhost"];

pub const CANONICALIZE_CASES: &[CanonicalizeCase] = &[CanonicalizeCase {
    input: CANONICAL_INPUT,
    expected: CANONICAL_OUTPUT,
}];

pub const VALID_BYPASS: &[&str] = &["example.com", "localhost"];
pub const INVALID_SIBLING_BYPASS: &[&str] = &["localhost"];

#[derive(Clone, Copy, Debug)]
pub struct SettingsExpectation {
    pub name: &'static str,
    pub http: Option<&'static str>,
    pub https: Option<&'static str>,
    pub all: Option<&'static str>,
    pub bypass: &'static [&'static str],
}

pub const SETTINGS_EXPECTATIONS: &[SettingsExpectation] = &[
    SettingsExpectation {
        name: "valid_http_with_bypass",
        http: Some("http://proxy.example.com:3128/"),
        https: None,
        all: None,
        bypass: VALID_BYPASS,
    },
    SettingsExpectation {
        name: "empty_direct",
        http: None,
        https: None,
        all: None,
        bypass: &[],
    },
    SettingsExpectation {
        name: "invalid_http_with_valid_https",
        http: None,
        https: Some("http://secure.example.com:8443/"),
        all: None,
        bypass: INVALID_SIBLING_BYPASS,
    },
];
