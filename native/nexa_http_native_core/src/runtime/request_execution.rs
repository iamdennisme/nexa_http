use crate::api::error::NativeError;
use crate::api::request::{NativeHttpHeader, NativeHttpRequest};
use crate::api::response::{NativeHttpOwnedBody, NativeHttpRawResponse};
use reqwest::header::{HeaderName, HeaderValue};
use reqwest::{Client, Method};
use std::collections::HashMap;
use std::str::FromStr;
use std::time::Duration;

pub(super) async fn execute_with_client(
    client: &Client,
    request: NativeHttpRequest,
) -> Result<NativeHttpRawResponse, NativeError> {
    let NativeHttpRequest {
        method,
        url,
        headers,
        body,
        timeout_ms,
    } = request;

    let method = Method::from_str(&method)
        .map_err(|error| NativeError::new("invalid_request", error.to_string()))?;

    let mut builder = client.request(method, &url);

    for header in &headers {
        let header_name = HeaderName::from_bytes(header.name.as_bytes()).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), header.name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        let header_value = HeaderValue::from_str(&header.value).map_err(|error| {
            let mut details = HashMap::new();
            details.insert("header".to_string(), header.name.clone());
            NativeError::new("invalid_request", error.to_string()).with_details(details)
        })?;
        builder = builder.header(header_name, header_value);
    }

    if let Some(timeout_ms) = timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if !body.is_empty() {
        builder = builder.body(body);
    }

    let response = builder
        .send()
        .await
        .map_err(|error| map_reqwest_error(error, &url))?;
    let status_code = response.status().as_u16();

    let mut headers = Vec::<NativeHttpHeader>::new();
    for (name, value) in response.headers() {
        headers.push(NativeHttpHeader {
            name: name.to_string(),
            value: value.to_str().unwrap_or_default().to_string(),
        });
    }

    let final_url = match reqwest::Url::parse(&url) {
        Ok(request_url) if response.url() == &request_url => None,
        _ => Some(response.url().to_string()),
    };
    let body = response
        .bytes()
        .await
        .map_err(|error| map_reqwest_error(error, &url))?;

    Ok(NativeHttpRawResponse {
        status_code,
        headers,
        body: NativeHttpOwnedBody::from_response_bytes(body),
        final_url,
    })
}

fn map_reqwest_error(error: reqwest::Error, url: &str) -> NativeError {
    let source_chain = reqwest_error_source_chain(&error);
    let details = if source_chain.is_empty() {
        None
    } else {
        Some(HashMap::from([("source_chain".to_string(), source_chain)]))
    };
    if error.is_timeout() {
        let mapped = NativeError::new("timeout", error.to_string())
            .with_timeout()
            .with_uri(url.to_string());
        return match details {
            Some(details) => mapped.with_details(details),
            None => mapped,
        };
    }

    let mapped = NativeError::new("network", error.to_string()).with_uri(url.to_string());
    match details {
        Some(details) => mapped.with_details(details),
        None => mapped,
    }
}

fn reqwest_error_source_chain(error: &reqwest::Error) -> String {
    let mut sources = Vec::<String>::new();
    let mut current = std::error::Error::source(error);
    while let Some(source) = current {
        sources.push(source.to_string());
        current = source.source();
    }
    sources.join(" <- ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn network_errors_preserve_the_reqwest_source_chain() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind test port");
        let address = listener.local_addr().expect("test port address");
        drop(listener);
        let url = format!("http://{address}/healthz");
        let client = reqwest::Client::builder()
            .no_proxy()
            .build()
            .expect("test client");
        let error = tokio::runtime::Runtime::new()
            .expect("test runtime")
            .block_on(client.get(&url).send())
            .expect_err("closed test port should reject the request");

        let mapped = map_reqwest_error(error, &url);

        assert_eq!(mapped.code, "network");
        assert_eq!(mapped.uri.as_deref(), Some(url.as_str()));
        assert!(
            mapped
                .details
                .as_ref()
                .and_then(|details| details.get("source_chain"))
                .is_some_and(|source_chain| !source_chain.is_empty()),
            "network errors should retain the underlying transport cause",
        );
    }
}
