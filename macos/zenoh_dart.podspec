#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zenoh_dart.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zenoh_dart'
  s.version          = '0.2.0'
  s.summary          = 'Dart and Flutter FFI bindings for Eclipse Zenoh'
  s.description      = <<-DESC
Dart and Flutter FFI bindings for Eclipse Zenoh middleware.
                       DESC
  s.homepage         = 'https://github.com/salimpia/zenoh_dart'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'M-PIA' => 'salimpia' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
