// https://github.com/Quick/Quick

import Quick
import Nimble


class SQLiteManagerSpec: QuickSpec {
	
	override func spec() {
		
        describe("Test moving database") {

			it ("1 + 1") {
				expect (1) == 2
			}
			
//			var database:SQLite!
//			
//			beforeEach({ 
//				database = SQLite()
//			})
//
//			it("did not initial") {
//
//				expect {
//					
//					try database.initializeDatabase("app_database", andExtension: "db")
//				
//				}.to(throwError { (error: ErrorType) in
//					
//					expect(error._domain) == SQLiteManagerError.kErrorDomain
//					expect(error._code) == SQLiteManagerError.kDatabaseFileDoesNotExistInAppBundleCode
//						
//				})
//				
//			}

		}
    }
}
