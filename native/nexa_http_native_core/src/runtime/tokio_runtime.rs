use tokio::runtime::{Builder as RuntimeBuilder, Runtime};

pub(crate) fn build_runtime() -> Runtime {
    RuntimeBuilder::new_multi_thread()
        .worker_threads(default_runtime_worker_threads())
        .enable_all()
        .build()
        .expect("failed to build tokio runtime")
}

fn default_runtime_worker_threads() -> usize {
    std::thread::available_parallelism()
        .map(|value| value.get().clamp(2, 8))
        .unwrap_or(4)
}

pub(crate) fn default_max_inflight_requests() -> usize {
    let parallelism = std::thread::available_parallelism()
        .map(|value| value.get())
        .unwrap_or(4);
    (parallelism * 32).clamp(64, 512)
}
