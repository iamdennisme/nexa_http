#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rust_net.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rust_net'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter HTTP SDK backed by a Rust reqwest core.'
  s.description      = <<-DESC
A Flutter HTTP SDK backed by a Rust reqwest core.
                       DESC
  s.homepage         = 'https://github.com/iamdennisme/rust_net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.preserve_paths = 'Libraries/**/*'
  s.resource_bundles = {
    'rust_net_native' => ['Libraries/librust_net_native.dylib']
  }

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'rust_net_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'MACOSX_DEPLOYMENT_TARGET' => '10.14'
  }
  s.swift_version = '5.0'
end
