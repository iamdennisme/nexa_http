Pod::Spec.new do |s|
  s.name             = 'rust_net'
  s.version          = '0.1.1'
  s.summary          = 'A Flutter HTTP SDK backed by a Rust reqwest core.'
  s.description      = <<-DESC
A Flutter HTTP SDK backed by a Rust reqwest core.
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
