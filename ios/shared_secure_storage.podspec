#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint shared_secure_storage.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'shared_secure_storage'
  s.version          = '0.1.0'
  s.summary          = 'Secure key-value storage shared between Dart and native code, readable before Flutter starts.'
  s.description      = <<-DESC
Secure key-value storage shared between Dart and native code, readable before Flutter starts.
                       DESC
  s.homepage         = 'https://github.com/open-voip-alliance/shared-secure-storage'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Open VoIP Alliance'
  s.source           = { :path => '.' }
  s.source_files = 'shared_secure_storage/Sources/shared_secure_storage/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'shared_secure_storage_privacy' => ['shared_secure_storage/Sources/shared_secure_storage/PrivacyInfo.xcprivacy']}
end
