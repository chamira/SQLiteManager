# SQLiteManager

"Everything Should Be Made as Simple as Possible, But Not Simpler" - Albert Einstein

Idea is to have a simple [Swift](https://developer.apple.com/swift/) interface to run basic [SQL](https://www.sqlite.org/lang.html) statements/queries such as CREATE TABLE, SELECT, INSERT, UPDATE and DELETE.
There are many iOS libraries that are well capable of doing complicated SQLite stuff but almost all of those libraries have more than what we need for small projects. 
Thus, the idea is to get rid of all the boilerplate code and keep things very simple. You write your own SQL.

Modeling, Handling objects, writing business logic is all up to the developers. 

[![CI Status](http://img.shields.io/travis/chamira/SQLiteManager.svg?style=flat)](https://travis-ci.org/chamira/SQLiteManager)
[![Version](https://img.shields.io/cocoapods/v/SQLiteManager.svg?style=flat)](http://cocoapods.org/pods/SQLiteManager)
[![License](https://img.shields.io/cocoapods/l/SQLiteManager.svg?style=flat)](http://cocoapods.org/pods/SQLiteManager)
[![Platform](https://img.shields.io/cocoapods/p/SQLiteManager.svg?style=flat)](http://cocoapods.org/pods/SQLiteManager)


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

Min iOS SDK 8.0<br /> 
Min tvOS SDK 9.0<br />

## Installation

SQLiteManager is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

## Usage

Drag and drop SQLite database file to project bundle. example database file name : ```app_test_database_1`` and extension is ``db`

```ruby
pod "SQLiteManager"
``

``` swift
import SQLiteManager

class ViewController: UIViewController {

	@IBOutlet weak var countLabel: UILabel!

	override func viewDidLoad() {
		super.viewDidLoad()

		let database =  try! SQLitePool.manager().initialize(database: "app_test_database_1", withExtension: "db")

		// on main thread
		let result = try! database.query("select count(*) as user_count from tb_user")
		if let r = result.results?.first!["user_count"] {
			self.countLabel.text = "\(r)"
		}

		// on background thread
		unowned let refSelf = self
		database.query("select count(*) as user_count from tb_user", successClosure: { (result) in

				if let r = result.results?.first!["user_count"] {
					refSelf.countLabel.text = "\(r)"
				}

			}, errorClosure: { (error) in
				print("Database Error",error)
			})

		//bind values
		let dob = NSDate(timeIntervalSince1970: 3600*24*3650)
		let profilePic  = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("chamira_fernando", ofType: "jpg")!)
		let _ = try! database.bindQuery("INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth, company_id, profile_picture) VALUES (?,?,?,?,?,?)", bindValues: ["Chameera","Fernando","some_user_name", NSNumber(double: dob.timeIntervalSince1970),NSNumber(int:1),profilePic!])

	}

}

``

## Legacy 

If you want to hook up with swift 2.3 point to swift2.3 branch 
```pod 'SQLiteManager', :git => 'https://github.com/chamira/SQLiteManager.git', :branch => 'swift2.3'``

## Author

Chamira Fernando, chamira.fdo@gmail.com, [Twitter](https://twitter.com/chamirafernando)


## License

SQLiteManager is available under the MIT license. See the LICENSE file for more info.
