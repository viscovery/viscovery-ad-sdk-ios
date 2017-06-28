

#
# Be sure to run `pod lib lint ViscoveryADSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = 'ViscoveryADSDK'
s.version          = '1.2.3'
s.summary          = 'Viscovery VidSense SDK'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

s.description      = <<-DESC
Integrate with Google IMA and provide simple APIs.
DESC

s.requires_arc = true
s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.0' }

s.homepage         = 'https://github.com/viscovery/viscovery-ad-sdk-ios'
s.license          = { :type => 'Apache 2', :file => 'LICENSE' }
s.author           = { 'boska lee' => 'boska.lee@viscovery.com' }
s.source           = { :git => 'https://github.com/viscovery/viscovery-ad-sdk-ios.git', :tag => s.version.to_s }

s.ios.deployment_target = '9.0'
s.ios.frameworks = 'AVFoundation'
s.source_files = 'ViscoveryADSDK/Classes/**/*'
s.resources = 'ViscoveryADSDK/Assets/*.xcassets'
s.dependency 'SWXMLHash', '~> 3.0'

end
