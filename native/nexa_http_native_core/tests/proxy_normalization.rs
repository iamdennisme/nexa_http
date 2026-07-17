#[path = "fixtures/proxy_normalization_cases.rs"]
mod fixtures;

use nexa_http_native_core::platform::{
    canonicalize_bypass_rules, clean_proxy_value, normalize_proxy_url, split_bypass_rules,
};

#[test]
fn shared_cleanup_cases_match_the_proxy_contract() {
    for case in fixtures::CLEANUP_CASES {
        assert_eq!(
            clean_proxy_value(case.input).as_deref(),
            case.expected,
            "unexpected cleanup for {:?}",
            case.input
        );
    }
}

#[test]
fn shared_url_cases_match_the_proxy_contract() {
    for case in fixtures::URL_CASES {
        assert_eq!(
            normalize_proxy_url(case.input, case.default_scheme).as_deref(),
            case.expected,
            "unexpected normalization for {:?}",
            case.input
        );
    }
}

#[test]
fn shared_bypass_split_cases_preserve_tokens() {
    for case in fixtures::SPLIT_CASES {
        let actual = split_bypass_rules(case.input);
        let expected = case
            .expected
            .iter()
            .map(|item| (*item).to_string())
            .collect::<Vec<_>>();
        assert_eq!(actual, expected, "unexpected split for {:?}", case.input);
    }
}

#[test]
fn shared_bypass_canonicalization_cases_sort_and_deduplicate() {
    for case in fixtures::CANONICALIZE_CASES {
        let input = case
            .input
            .iter()
            .map(|item| (*item).to_string())
            .collect::<Vec<_>>();
        let expected = case
            .expected
            .iter()
            .map(|item| (*item).to_string())
            .collect::<Vec<_>>();
        assert_eq!(canonicalize_bypass_rules(input), expected);
    }
}
