use crate::platform::{
    PlatformRuntimeState, PlatformRuntimeView, ProxyConfigSource, ProxySettings, RefreshMode,
};
use std::sync::Arc;
use std::sync::RwLock;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

pub struct ManagedProxyState<S: ProxyConfigSource> {
    inner: Arc<ManagedProxyStateInner<S>>,
}

struct ManagedProxyStateInner<S: ProxyConfigSource> {
    source: S,
    generation: AtomicU64,
    snapshot: RwLock<ProxySettings>,
    refresh_started: AtomicBool,
}

impl<S: ProxyConfigSource> ManagedProxyState<S> {
    pub fn new(source: S) -> Self {
        let initial_snapshot = source.load_current();
        Self {
            inner: Arc::new(ManagedProxyStateInner {
                source,
                generation: AtomicU64::new(0),
                snapshot: RwLock::new(initial_snapshot),
                refresh_started: AtomicBool::new(false),
            }),
        }
    }

    pub fn with_background_refresh(source: S, thread_name: impl Into<String>) -> Self {
        let state = Self::new(source);
        state.spawn_refresh_worker(thread_name.into());
        state
    }

    pub fn refresh_mode(&self) -> RefreshMode {
        self.inner.source.refresh_mode()
    }

    pub fn current_proxy_snapshot(&self) -> ProxySettings {
        self.inner
            .snapshot
            .read()
            .expect("proxy runtime state poisoned")
            .clone()
    }

    pub fn refresh_now(&self) -> bool {
        let next_snapshot = self.inner.source.load_current();
        let mut snapshot = self
            .inner
            .snapshot
            .write()
            .expect("proxy runtime state poisoned");
        if *snapshot == next_snapshot {
            return false;
        }

        *snapshot = next_snapshot;
        self.inner.generation.fetch_add(1, Ordering::SeqCst);
        true
    }

    pub fn current_platform_state(&self) -> PlatformRuntimeView {
        PlatformRuntimeView::with_proxy_settings(
            self.proxy_generation(),
            self.current_proxy_snapshot(),
        )
    }

    pub fn proxy_generation(&self) -> u64 {
        self.inner.generation.load(Ordering::SeqCst)
    }

    pub fn spawn_refresh_worker(&self, thread_name: String) {
        let RefreshMode::Polling { interval } = self.refresh_mode() else {
            return;
        };

        if self
            .inner
            .refresh_started
            .swap(true, Ordering::SeqCst)
        {
            return;
        }

        let state = self.clone();
        let _ = std::thread::Builder::new()
            .name(thread_name)
            .spawn(move || {
                loop {
                    std::thread::sleep(interval);
                    state.refresh_now();
                }
            });
    }
}

impl<S: ProxyConfigSource> Clone for ManagedProxyState<S> {
    fn clone(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
        }
    }
}

impl<S: ProxyConfigSource> PlatformRuntimeState for ManagedProxyState<S> {
    fn proxy_generation(&self) -> u64 {
        ManagedProxyState::proxy_generation(self)
    }

    fn current_platform_state(&self) -> PlatformRuntimeView {
        ManagedProxyState::current_platform_state(self)
    }
}
