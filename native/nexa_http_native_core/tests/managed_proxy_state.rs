use nexa_http_native_core::platform::{ProxyConfigSource, ProxySettings, RefreshMode};
use nexa_http_native_core::runtime::ManagedProxyState;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

#[derive(Clone)]
struct TestSource {
    loads: Arc<AtomicUsize>,
    snapshots: Arc<Vec<ProxySettings>>,
    refresh_mode: RefreshMode,
}

impl ProxyConfigSource for TestSource {
    fn load_current(&self) -> ProxySettings {
        let index = self.loads.fetch_add(1, Ordering::Relaxed);
        self.snapshots
            .get(index)
            .cloned()
            .or_else(|| self.snapshots.last().cloned())
            .unwrap_or_default()
    }

    fn refresh_mode(&self) -> RefreshMode {
        self.refresh_mode
    }
}

#[test]
fn managed_proxy_state_tracks_generation_and_latest_snapshot() {
    let source = TestSource {
        loads: Arc::new(AtomicUsize::new(0)),
        snapshots: Arc::new(vec![
            ProxySettings::default(),
            ProxySettings {
                http: Some("http://127.0.0.1:8888".to_string()),
                ..ProxySettings::default()
            },
        ]),
        refresh_mode: RefreshMode::Static,
    };

    let state = ManagedProxyState::new(source);
    let initial = state.current_platform_state();
    assert_eq!(initial.proxy_generation, 0);
    assert_eq!(initial.platform_features.proxy, ProxySettings::default());

    assert!(state.refresh_now());
    let updated = state.current_platform_state();
    assert_eq!(updated.proxy_generation, 1);
    assert_eq!(
        updated.platform_features.proxy.http.as_deref(),
        Some("http://127.0.0.1:8888"),
    );
}

#[test]
fn managed_proxy_state_reports_platform_refresh_mode() {
    let source = TestSource {
        loads: Arc::new(AtomicUsize::new(0)),
        snapshots: Arc::new(vec![ProxySettings::default()]),
        refresh_mode: RefreshMode::Polling {
            interval: Duration::from_secs(7),
        },
    };

    let state = ManagedProxyState::new(source);
    assert_eq!(
        state.refresh_mode(),
        RefreshMode::Polling {
            interval: Duration::from_secs(7),
        }
    );
}

#[test]
fn managed_proxy_state_does_not_advance_generation_when_snapshot_is_unchanged() {
    let settings = ProxySettings {
        http: Some("http://127.0.0.1:8888".to_string()),
        ..ProxySettings::default()
    };
    let source = TestSource {
        loads: Arc::new(AtomicUsize::new(0)),
        snapshots: Arc::new(vec![settings.clone(), settings]),
        refresh_mode: RefreshMode::Static,
    };

    let state = ManagedProxyState::new(source);
    assert!(!state.refresh_now());
    assert_eq!(state.proxy_generation(), 0);
}

#[test]
fn construction_boundary_refresh_updates_snapshot_without_background_polling() {
    let loads = Arc::new(AtomicUsize::new(0));
    let source = TestSource {
        loads: Arc::clone(&loads),
        snapshots: Arc::new(vec![
            ProxySettings::default(),
            ProxySettings {
                http: Some("http://127.0.0.1:9999".to_string()),
                ..ProxySettings::default()
            },
        ]),
        refresh_mode: RefreshMode::ConstructionBoundary,
    };

    let state = ManagedProxyState::new(source);
    assert_eq!(loads.load(Ordering::Relaxed), 1);

    assert!(state.refresh_for_client_construction());
    assert_eq!(loads.load(Ordering::Relaxed), 2);
    assert_eq!(
        state
            .current_platform_state()
            .platform_features
            .proxy
            .http
            .as_deref(),
        Some("http://127.0.0.1:9999"),
    );

    state.spawn_refresh_worker("should-not-start".to_string());
    assert_eq!(
        loads.load(Ordering::Relaxed),
        2,
        "construction-boundary sources must not start a polling worker",
    );
}
