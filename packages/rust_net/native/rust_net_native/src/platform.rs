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

impl ProxySettings {
    pub(crate) fn is_empty(&self) -> bool {
        self.http.is_none() && self.https.is_none() && self.all.is_none()
    }
}

#[cfg(target_os = "linux")]
#[path = "platform/linux.rs"]
mod current_os;
#[cfg(not(target_os = "linux"))]
mod current_os {
    use super::PlatformFeatures;

    pub(crate) fn current() -> PlatformFeatures {
        PlatformFeatures::default()
    }
}

pub(crate) fn current_platform_features() -> PlatformFeatures {
    current_os::current()
}
