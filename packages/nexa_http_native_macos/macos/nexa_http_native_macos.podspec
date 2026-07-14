#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint nexa_http_native_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'nexa_http_native_macos'
  s.version          = '2.0.0'
  s.summary          = 'macOS carrier package for nexa_http native artifacts.'
  s.description      = <<-DESC
macOS carrier package for nexa_http native artifacts.
                       DESC
  s.homepage         = 'https://github.com/iamdennisme/nexa_http'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # Add a privacy resource only if the plugin begins using a required-reason API.

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'MACOSX_DEPLOYMENT_TARGET' => '10.14'
  }
  s.swift_version = '5.0'
end
