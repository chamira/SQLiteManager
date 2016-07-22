// https://github.com/Quick/Quick

import Quick
import Nimble
import SQLiteManager

class SQLiteManagerNoDatabaseSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager()") {
			
			it ("initialize database catch no database") {
				
					expect {
					
						try SQLitePool.manager().initializeDatabase("app_test_database", andExtension: "db")
						
					}.to(throwError {(error:ErrorType) in
						
						expect(SQLiteManagerError.kDatabaseFileDoesNotExistInAppBundleCode) == error._code
						expect(SQLiteManagerError.kErrorDomain) == error._domain
						
					})
			}
		
		}
	}
}


class SQLiteManagerDataabaseActionsSpec: QuickSpec {
	
	override func spec() {
		describe("SQLite.manager()") {
			
			let database = SQLitePool.manager()
			
//			try! database.initializeDatabase("app_test_database", andExtension: "db")
//			it ("Database name") {
//				expect("app_test_database.db") == database.databaseName
//			}
		}
	}
}