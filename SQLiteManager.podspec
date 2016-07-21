#
# Be sure to run `pod lib lint SQLiteManager.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SQLiteManager'
  s.version          = '0.1.0'
  s.summary          = 'Simple SQL Manager class to do operations such as open database, close database, insert, update, delete and select'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Simple DatabaseManager class to do operations like on SQLite database such as ,open database, close database, insert, update, delete and select, This class is a Singleton and can be accessed via sharedManager.
                       DESC

  s.homepage         = 'https://github.com/chamira/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chamira Fernando' => 'chamira.fdo@gmail.com' }
  s.source           = { :git => 'https://github.com/chamira/SQLiteManager.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/chamirafernando'

  s.ios.deployment_target = '8.0'

  s.source_files = 'SQLiteManager/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SQLiteManager' => ['SQLiteManager/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
s.library = 'sqlite3'
s.dependency 'sqlite3'
end
