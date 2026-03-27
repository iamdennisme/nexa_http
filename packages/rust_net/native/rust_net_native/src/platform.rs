#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct PlatformFeatures {
    pub(crate) proxy: ProxySettings,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(crate) struct ProxySettings {
    pub(crate) http: Option<String>,
    pub(crate) https: Option<String>,
    pub(crate) all: Option<String>,
    pub(crate) bypass: Vec<String>,
}

impl PlatformFeatures {
    pub(crate) fn signature(&self) -> String {
        format!(
            "http={}|https={}|all={}|no={}",
            self.proxy.http.as_deref().unwrap_or(""),
            self.proxy.https.as_deref().unwrap_or(""),
            self.proxy.all.as_deref().unwrap_or(""),
            self.proxy.bypass.join(","),
        )
    }
}

#[cfg(target_os = "android")]
#[path = "platform/android.rs"]
mod current_os;
#[cfg(target_os = "ios")]
#[path = "platform/ios.rs"]
mod current_os;
#[cfg(target_os = "macos")]
#[path = "platform/macos.rs"]
mod current_os;
#[cfg(target_os = "windows")]
#[path = "platform/windows.rs"]
mod current_os;
#[cfg(target_os = "linux")]
#[path = "platform/linux.rs"]
mod current_os;
#[cfg(not(any(
    target_os = "android",
    target_os = "ios",
    target_os = "macos",
    target_os = "windows",
    target_os = "linux",
)))]
mod current_os {
    use super::PlatformFeatures;

    pub(crate) fn current() -> PlatformFeatures {
        PlatformFeatures::default()
    }
}

pub(crate) fn current_platform_features() -> PlatformFeatures {
    current_os::current()
}
