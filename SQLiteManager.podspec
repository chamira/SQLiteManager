Pod::Spec.new do |s|
  s.name             = 'SQLiteManager'
  s.version          = '0.1.7'
  s.summary          = 'Simple SQLite Manager class to do operations such as open database, close database, insert, update, delete and select'

  s.description      = <<-DESC
Idea is to have a simple [Swift](https://developer.apple.com/swift/) interface to run basic [SQL](https://www.sqlite.org/lang.html) statements such as CREATE TABLE, SELECT, INSERT, UPDATE and DELETE.
There are many iOS libraries that are well capable of doing complicated SQLite stuff but almost all of those libraries have more than what we need for small projects.
Thus, the idea is to get rid of all the boilerplate code and keep things very simple. You write your own SQL.

Handling objects, writing business logic is all up to the developers.
                       DESC

    s.homepage         = 'https://github.com/chamira/'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Chamira Fernando' => 'chamira.fdo@gmail.com' }
    s.source           = { :git => 'https://github.com/chamira/SQLiteManager.git', :tag => s.version.to_s }
    s.social_media_url = 'https://twitter.com/chamirafernando'
    s.ios.deployment_target = '8.0'
    s.tvos.deployment_target = '9.0'
    s.source_files = 'SQLiteManager/Classes/**/*'
    s.library = 'sqlite3'
    s.dependency 'sqlite3'
end
