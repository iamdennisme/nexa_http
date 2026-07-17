use crate::api::error::NativeError;
use crate::api::request::NativeHttpClientConfig;
use crate::platform::{PlatformFeatures, PlatformRuntimeState, apply_proxy_strategy};
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::{Client, ClientBuilder};
use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

pub(super) struct ClientRegistry {
    clients: Mutex<HashMap<u64, ClientEntry>>,
    next_client_id: AtomicU64,
}

impl ClientRegistry {
    pub(super) fn new() -> Self {
        Self {
            clients: Mutex::new(HashMap::new()),
            next_client_id: AtomicU64::new(1),
        }
    }

    pub(super) fn count(&self) -> usize {
        self.clients.lock().unwrap().len()
    }

    pub(super) fn create(
        &self,
        config: NativeHttpClientConfig,
        platform_features: &PlatformFeatures,
        proxy_generation: u64,
    ) -> Result<u64, NativeError> {
        let client = build_client(&config, platform_features)?;
        let client_id = self.next_client_id.fetch_add(1, Ordering::Relaxed);
        let entry = ClientEntry {
            client,
            config,
            platform_features_signature: platform_features.signature(),
            proxy_generation,
        };
        self.clients.lock().unwrap().insert(client_id, entry);
        Ok(client_id)
    }

    pub(super) fn close(&self, client_id: u64) {
        self.clients.lock().unwrap().remove(&client_id);
    }

    pub(super) fn resolve_for_request<P: PlatformRuntimeState>(
        &self,
        capabilities: &P,
        client_id: u64,
        request_url: &str,
    ) -> Result<Client, NativeError> {
        loop {
            let plan = {
                let clients = self.clients.lock().unwrap();
                let entry = clients
                    .get(&client_id)
                    .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;
                let current_generation = capabilities.proxy_generation();
                if entry.proxy_generation == current_generation {
                    return Ok(entry.client.clone());
                }

                ClientRefreshPlan {
                    previous_generation: entry.proxy_generation,
                    previous_signature: entry.platform_features_signature.clone(),
                    config: entry.config.clone(),
                    current_generation,
                }
            };

            let current_state = capabilities.current_platform_state();
            if current_state.proxy_generation != plan.current_generation {
                continue;
            }
            let next_signature = current_state.platform_features.signature();
            let rebuilt_client = if next_signature == plan.previous_signature {
                None
            } else {
                Some(
                    build_client(&plan.config, &current_state.platform_features)
                        .map_err(|error| error.with_uri(request_url.to_string()))?,
                )
            };

            let mut clients = self.clients.lock().unwrap();
            let entry = clients
                .get_mut(&client_id)
                .ok_or_else(|| NativeError::new("invalid_client", "Unknown client handle."))?;

            if entry.proxy_generation != plan.previous_generation
                || entry.platform_features_signature != plan.previous_signature
            {
                continue;
            }

            if let Some(client) = rebuilt_client {
                entry.client = client;
                entry.platform_features_signature = next_signature;
            }
            entry.proxy_generation = current_state.proxy_generation;
            return Ok(entry.client.clone());
        }
    }
}

struct ClientEntry {
    client: Client,
    config: NativeHttpClientConfig,
    platform_features_signature: String,
    proxy_generation: u64,
}

#[derive(Clone)]
struct ClientRefreshPlan {
    previous_generation: u64,
    previous_signature: String,
    config: NativeHttpClientConfig,
    current_generation: u64,
}

fn build_client(
    config: &NativeHttpClientConfig,
    platform_features: &PlatformFeatures,
) -> Result<Client, NativeError> {
    let mut builder = ClientBuilder::new();

    builder = builder.pool_max_idle_per_host(usize::MAX).tcp_nodelay(true);

    if let Some(timeout_ms) = config.timeout_ms.filter(|value| *value > 0) {
        builder = builder.timeout(Duration::from_millis(timeout_ms));
    }

    if let Some(user_agent) = config.user_agent.as_ref().filter(|value| !value.is_empty()) {
        builder = builder.user_agent(user_agent.clone());
    }

    if !config.default_headers.is_empty() {
        builder =
            builder.default_headers(build_headers(&config.default_headers, "invalid_config")?);
    }
    builder = apply_proxy_strategy(builder, platform_features)
        .map_err(|error| NativeError::new("invalid_proxy", error))?;

    builder
        .build()
        .map_err(|error| NativeError::new("invalid_config", error.to_string()))
}

fn build_headers(
    headers: &HashMap<String, String>,
    error_code: &'static str,
) -> Result<HeaderMap, NativeError> {
    let mut header_map = HeaderMap::new();
    for (name, value) in headers {
        let header_name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        let header_value = HeaderValue::from_str(value)
            .map_err(|error| NativeError::new(error_code, error.to_string()))?;
        header_map.insert(header_name, header_value);
    }
    Ok(header_map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::platform::{PlatformRuntimeView, ProxySettings};
    use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
    use std::sync::{Arc, Mutex};

    #[derive(Clone)]
    struct TestCapabilities {
        proxy: Arc<Mutex<ProxySettings>>,
        state_calls: Arc<AtomicUsize>,
        generation: Arc<AtomicU64>,
        delay_refresh: Arc<AtomicBool>,
    }

    impl TestCapabilities {
        fn new() -> Self {
            Self {
                proxy: Arc::new(Mutex::new(ProxySettings::default())),
                state_calls: Arc::new(AtomicUsize::new(0)),
                generation: Arc::new(AtomicU64::new(0)),
                delay_refresh: Arc::new(AtomicBool::new(false)),
            }
        }

        fn set_generation(&self, generation: u64, proxy: ProxySettings) {
            *self.proxy.lock().unwrap() = proxy;
            self.generation.store(generation, Ordering::Relaxed);
        }
    }

    impl PlatformRuntimeState for TestCapabilities {
        fn proxy_generation(&self) -> u64 {
            self.generation.load(Ordering::Relaxed)
        }

        fn current_platform_state(&self) -> PlatformRuntimeView {
            self.state_calls.fetch_add(1, Ordering::Relaxed);
            if self.delay_refresh.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(50));
            }
            PlatformRuntimeView::with_proxy_settings(
                self.generation.load(Ordering::Relaxed),
                self.proxy.lock().unwrap().clone(),
            )
        }
    }

    fn registry_with_client() -> (Arc<ClientRegistry>, u64) {
        let registry = Arc::new(ClientRegistry::new());
        let initial_state = PlatformRuntimeView::with_proxy_settings(0, ProxySettings::default());
        let client_id = registry
            .create(
                NativeHttpClientConfig {
                    default_headers: HashMap::new(),
                    timeout_ms: None,
                    user_agent: None,
                },
                &initial_state.platform_features,
                initial_state.proxy_generation,
            )
            .unwrap();
        (registry, client_id)
    }

    #[test]
    fn unchanged_generation_reuses_the_existing_client_without_reading_platform_state() {
        let capabilities = TestCapabilities::new();
        let (registry, client_id) = registry_with_client();

        registry
            .resolve_for_request(&capabilities, client_id, "https://example.com")
            .unwrap();
        registry
            .resolve_for_request(&capabilities, client_id, "https://example.com")
            .unwrap();

        assert_eq!(capabilities.state_calls.load(Ordering::Relaxed), 0);
    }

    #[test]
    fn changed_signature_rebuilds_once_then_returns_to_the_fast_path() {
        let capabilities = TestCapabilities::new();
        let (registry, client_id) = registry_with_client();
        capabilities.set_generation(
            1,
            ProxySettings {
                http: Some("http://127.0.0.1:8888".to_string()),
                ..ProxySettings::default()
            },
        );

        registry
            .resolve_for_request(&capabilities, client_id, "https://example.com")
            .unwrap();
        registry
            .resolve_for_request(&capabilities, client_id, "https://example.com")
            .unwrap();

        assert_eq!(capabilities.state_calls.load(Ordering::Relaxed), 1);
    }

    #[test]
    fn failed_rebuild_leaves_the_old_generation_for_the_next_request_to_retry() {
        let capabilities = TestCapabilities::new();
        let (registry, client_id) = registry_with_client();
        capabilities.set_generation(
            1,
            ProxySettings {
                http: Some("not a valid proxy url".to_string()),
                ..ProxySettings::default()
            },
        );

        for _ in 0..2 {
            let error = registry
                .resolve_for_request(&capabilities, client_id, "https://example.com")
                .expect_err("invalid proxy refresh should fail");
            assert_eq!(error.code, "invalid_proxy");
        }

        assert_eq!(capabilities.state_calls.load(Ordering::Relaxed), 2);
    }

    #[test]
    fn concurrent_generation_refresh_settles_back_to_the_fast_path() {
        let capabilities = TestCapabilities::new();
        let (registry, client_id) = registry_with_client();
        capabilities.delay_refresh.store(true, Ordering::Relaxed);
        capabilities.set_generation(1, ProxySettings::default());

        let mut threads = Vec::new();
        for _ in 0..8 {
            let capabilities = capabilities.clone();
            let registry = Arc::clone(&registry);
            threads.push(std::thread::spawn(move || {
                registry
                    .resolve_for_request(&capabilities, client_id, "https://example.com")
                    .unwrap();
            }));
        }
        for thread in threads {
            thread.join().unwrap();
        }

        let calls_after_concurrency = capabilities.state_calls.load(Ordering::Relaxed);
        assert!(calls_after_concurrency > 0);
        registry
            .resolve_for_request(&capabilities, client_id, "https://example.com")
            .unwrap();
        assert_eq!(
            capabilities.state_calls.load(Ordering::Relaxed),
            calls_after_concurrency,
        );
    }
}
