use super::*;
use crate::platform::{PlatformRuntimeView, ProxySettings};
use std::collections::HashMap;
use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, LazyLock, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone)]
struct CountingCapabilities {
    platform_state_calls: Arc<AtomicUsize>,
}

impl PlatformRuntimeState for CountingCapabilities {
    fn proxy_generation(&self) -> u64 {
        0
    }

    fn current_platform_state(&self) -> PlatformRuntimeView {
        self.platform_state_calls.fetch_add(1, Ordering::Relaxed);
        PlatformRuntimeView::with_proxy_settings(0, ProxySettings::default())
    }
}

struct TestRequestArgs {
    _method: CString,
    _url: CString,
    args: NexaHttpRequestArgs,
}

impl TestRequestArgs {
    fn new(method: &str, url: &str, timeout_ms: u64) -> Self {
        let method = CString::new(method).expect("request method");
        let url = CString::new(url).expect("request url");
        let args = NexaHttpRequestArgs {
            method_ptr: method.as_ptr() as *const c_char,
            method_len: method.as_bytes().len(),
            url_ptr: url.as_ptr() as *const c_char,
            url_len: url.as_bytes().len(),
            headers_ptr: std::ptr::null(),
            headers_len: 0,
            body_ptr: std::ptr::null_mut(),
            body_len: 0,
            body_owned: 0,
            timeout_ms,
            has_timeout: 1,
        };
        Self {
            _method: method,
            _url: url,
            args,
        }
    }

    fn as_args(&self) -> *const NexaHttpRequestArgs {
        &self.args
    }
}

struct TestClientConfigArgs {
    args: NexaHttpClientConfigArgs,
}

impl TestClientConfigArgs {
    fn new() -> Self {
        Self {
            args: NexaHttpClientConfigArgs {
                default_headers_ptr: std::ptr::null(),
                default_headers_len: 0,
                user_agent_ptr: std::ptr::null(),
                user_agent_len: 0,
                timeout_ms: 0,
                has_timeout: 0,
            },
        }
    }

    fn as_args(&self) -> *const NexaHttpClientConfigArgs {
        &self.args
    }
}

static NEXT_TEST_REQUEST_ID: AtomicU64 = AtomicU64::new(1);
static BLOCKING_CALLBACKS: LazyLock<Mutex<HashMap<u64, BlockingCallback>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

struct BlockingCallback {
    result_sender: Sender<usize>,
    release_receiver: Receiver<()>,
}

unsafe extern "C" fn capture_and_block_test_result(
    request_id: u64,
    result: *mut NexaHttpBinaryResult,
) {
    if let Some(callback) = BLOCKING_CALLBACKS.lock().unwrap().remove(&request_id) {
        let _ = callback.result_sender.send(result as usize);
        let _ = callback
            .release_receiver
            .recv_timeout(Duration::from_secs(1));
    }
}

#[test]
fn cancel_returns_zero_after_callback_commit_and_the_callback_is_delivered() {
    let runtime = NexaHttpRuntime::new(CountingCapabilities {
        platform_state_calls: Arc::new(AtomicUsize::new(0)),
    });
    let config = TestClientConfigArgs::new();
    let request = TestRequestArgs::new("GET", "http://127.0.0.1:9/ping", 1);
    let client_id = runtime.create_client(config.as_args());
    assert_ne!(client_id, 0);

    let request_id = NEXT_TEST_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
    let (result_sender, result_receiver) = mpsc::channel();
    let (release_sender, release_receiver) = mpsc::channel();
    BLOCKING_CALLBACKS.lock().unwrap().insert(
        request_id,
        BlockingCallback {
            result_sender,
            release_receiver,
        },
    );

    assert_eq!(
        runtime.execute_async(
            client_id,
            request_id,
            request.as_args(),
            Some(capture_and_block_test_result),
        ),
        1,
    );
    let result = result_receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("the committed callback must be delivered");

    let cancel_result = runtime.cancel_request(client_id, request_id);
    release_sender
        .send(())
        .expect("the blocked callback should still be waiting");
    unsafe {
        NexaHttpRuntime::<CountingCapabilities>::binary_result_free(
            result as *mut NexaHttpBinaryResult,
        );
    }

    let deadline = Instant::now() + Duration::from_secs(1);
    while runtime
        .inner
        .inflight_requests
        .contains(client_id, request_id)
    {
        assert!(
            Instant::now() < deadline,
            "the delivered callback should drain inflight tracking",
        );
        std::thread::yield_now();
    }

    assert_eq!(cancel_result, 0);
}
