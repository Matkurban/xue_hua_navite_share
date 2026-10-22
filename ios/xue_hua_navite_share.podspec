#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_navite_share.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_navite_share'
  s.version          = '0.1.0'
  s.summary          = 'Cross-platform native share plugin for Flutter.'
  s.description      = <<-DESC
A comprehensive cross-platform native share Flutter plugin supporting Android, iOS, macOS, Windows, Linux, and Web.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_navite_share'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_navite_share/Sources/xue_hua_navite_share/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'xue_hua_navite_share_privacy' => ['xue_hua_navite_share/Sources/xue_hua_navite_share/PrivacyInfo.xcprivacy']}
end
