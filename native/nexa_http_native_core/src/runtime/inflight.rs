use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::task::AbortHandle;

pub(super) struct InflightRequests {
    states: Mutex<HashMap<InflightRequestKey, InflightRequestState>>,
}

impl InflightRequests {
    pub(super) fn new() -> Self {
        Self {
            states: Mutex::new(HashMap::new()),
        }
    }

    pub(super) fn register(&self, client_id: u64, request_id: u64) -> InflightRequestKey {
        let key = InflightRequestKey {
            client_id,
            request_id,
        };
        self.states
            .lock()
            .unwrap()
            .insert(key, InflightRequestState::Pending);
        key
    }

    pub(super) fn guard(self: &Arc<Self>, key: InflightRequestKey) -> InflightRequestGuard {
        InflightRequestGuard {
            requests: Arc::clone(self),
            key,
        }
    }

    pub(super) fn install_abort_handle(
        &self,
        key: InflightRequestKey,
        abort_handle: AbortHandle,
    ) -> bool {
        let mut states = self.states.lock().unwrap();
        match states.get_mut(&key) {
            Some(state @ InflightRequestState::Pending) => {
                *state = InflightRequestState::Active(abort_handle);
                false
            }
            Some(InflightRequestState::CanceledPending) => {
                states.remove(&key);
                true
            }
            Some(InflightRequestState::Active(_))
            | Some(InflightRequestState::CallbackCommitted) => false,
            None => true,
        }
    }

    pub(super) fn cancel(&self, client_id: u64, request_id: u64) -> bool {
        let key = InflightRequestKey {
            client_id,
            request_id,
        };
        let abort_handle = {
            let mut states = self.states.lock().unwrap();
            match states.get_mut(&key) {
                Some(state @ InflightRequestState::Pending) => {
                    *state = InflightRequestState::CanceledPending;
                    None
                }
                Some(InflightRequestState::CanceledPending) => None,
                Some(InflightRequestState::Active(_)) => match states.remove(&key) {
                    Some(InflightRequestState::Active(abort_handle)) => Some(abort_handle),
                    _ => None,
                },
                Some(InflightRequestState::CallbackCommitted) | None => return false,
            }
        };

        if let Some(abort_handle) = abort_handle {
            abort_handle.abort();
        }
        true
    }

    pub(super) fn commit_callback(&self, key: InflightRequestKey) -> bool {
        let mut states = self.states.lock().unwrap();
        match states.get_mut(&key) {
            Some(state @ (InflightRequestState::Pending | InflightRequestState::Active(_))) => {
                *state = InflightRequestState::CallbackCommitted;
                true
            }
            Some(InflightRequestState::CanceledPending)
            | Some(InflightRequestState::CallbackCommitted)
            | None => false,
        }
    }

    #[cfg(test)]
    pub(super) fn contains(&self, client_id: u64, request_id: u64) -> bool {
        self.states
            .lock()
            .unwrap()
            .contains_key(&InflightRequestKey {
                client_id,
                request_id,
            })
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub(super) struct InflightRequestKey {
    client_id: u64,
    request_id: u64,
}

enum InflightRequestState {
    Pending,
    CanceledPending,
    Active(AbortHandle),
    CallbackCommitted,
}

pub(super) struct InflightRequestGuard {
    requests: Arc<InflightRequests>,
    key: InflightRequestKey,
}

impl Drop for InflightRequestGuard {
    fn drop(&mut self) {
        self.requests.states.lock().unwrap().remove(&self.key);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pending_cancel_is_retained_until_the_abort_handle_is_installed() {
        let requests = Arc::new(InflightRequests::new());
        let key = requests.register(7, 11);

        assert!(requests.cancel(7, 11));
        assert!(matches!(
            requests.states.lock().unwrap().get(&key),
            Some(InflightRequestState::CanceledPending)
        ));

        let runtime = tokio::runtime::Runtime::new().unwrap();
        let task = runtime.spawn(std::future::pending::<()>());
        assert!(requests.install_abort_handle(key, task.abort_handle()));
        task.abort();
        runtime.block_on(async {
            assert!(task.await.is_err());
        });
        assert!(!requests.contains(7, 11));
    }

    #[test]
    fn active_cancel_aborts_work_and_suppresses_callback_commit() {
        let requests = Arc::new(InflightRequests::new());
        let key = requests.register(7, 12);
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let task = runtime.spawn(std::future::pending::<()>());
        assert!(!requests.install_abort_handle(key, task.abort_handle()));

        assert!(requests.cancel(7, 12));
        assert!(!requests.contains(7, 12));
        assert!(!requests.commit_callback(key));
        runtime.block_on(async {
            assert!(task.await.is_err());
        });
    }

    #[test]
    fn unknown_cancel_is_not_accepted() {
        let requests = InflightRequests::new();

        assert!(!requests.cancel(404, 999));
    }

    #[test]
    fn callback_commit_wins_before_later_cancel() {
        let requests = Arc::new(InflightRequests::new());
        let key = requests.register(7, 13);
        let _guard = requests.guard(key);

        assert!(requests.commit_callback(key));
        assert!(!requests.cancel(7, 13));
    }
}
