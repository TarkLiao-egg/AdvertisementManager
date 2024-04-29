#
# Be sure to run `pod lib lint ${POD_NAME}.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TAdManager_iOS'
  s.version          = '1.0.5'
  s.summary          = 'Load ads and play'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/TarkLiao-egg/TAdManager_iOS'
  s.license          = { :type => 'Tark', :file => 'LICENSE' }
  s.author           = { 'Tark' => 'egg251551155@gmail.com' }
  s.source           = { :git => 'https://github.com/TarkLiao-egg/TAdManager_iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'TAdManager_iOS/Classes/**/*'
  
  # s.resource_bundles = {
  #   '${POD_NAME}' => ['${POD_NAME}/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
