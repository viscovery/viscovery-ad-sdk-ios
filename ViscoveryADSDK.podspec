

#
# Be sure to run `pod lib lint ViscoveryADSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = 'ViscoveryADSDK'
s.version          = '1.2.0'
s.summary          = 'Viscovery VidSense SDK'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

s.description      = <<-DESC
Integrate with Google IMA and provide simple APIs.
DESC

s.homepage         = 'https://github.com/viscovery/viscovery-ios-ad-sdk'
s.license          = { :type => 'Apache 2', :file => 'LICENSE' }
s.author           = { 'boska lee' => 'boska.lee@viscovery.com' }
s.source           = { :git => 'https://github.com/viscovery/viscovery-ios-ad-sdk.git', :tag => s.version.to_s }

s.ios.deployment_target = '9.0'
s.source_files = 'ViscoveryADSDK/Classes/**/*'
s.dependency 'GoogleAds-IMA-iOS-SDK', '~> 3.5'
s.dependency 'SWXMLHash', '~> 3.0'
s.dependency 'Cartography', '~> 1.1'
end

