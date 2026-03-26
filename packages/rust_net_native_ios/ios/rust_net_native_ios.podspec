Pod::Spec.new do |s|
  s.name             = 'rust_net_native_ios'
  s.version          = '0.1.1'
  s.summary          = 'iOS carrier package for rust_net native artifacts.'
  s.description      = <<-DESC
iOS carrier package for rust_net native artifacts.
                       DESC
  s.homepage         = 'https://github.com/iamdennisme/rust_net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.preserve_paths = 'Frameworks/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
