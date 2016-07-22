//
//  ViewController.swift
//  SQLiteManager
//
//  Created by Chamira Fernando on 07/19/2016.
//  Copyright (c) 2016 Chamira Fernando. All rights reserved.
//

import UIKit
import SQLiteManager

class ViewController: UIViewController {

	@IBOutlet weak var countLabel: UILabel!
	
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
		let test_database =  try! SQLitePool.manager().initializeDatabase("app_test_database_1", andExtension: "db")
		
		test_database.log = false
		
		unowned let weakSelf = self
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { 
			let start = NSDate()
//			for i in 1...100000 {
//				let fname = "Nilakshi-\(i)"
//				let lname = "Peries-\(i)"
//				
//				let has = try! test_database.query(sqlStatement: "select first_name,last_name as user_count from tb_user where first_name = '\(fname)' and last_name = '\(lname)'")
//				if (has.affectedRowCount == 0) {
//					let _ = try! test_database.query(sqlStatement: "INSERT INTO 'tb_user' (first_name, last_name, username) VALUES ('\(fname)','\(lname)', 'ane manda-\(i+i)');")
//				}
//				
//				let count = try! test_database.query(sqlStatement: "select count(*) as user_count from tb_user")
//				if let result = count.results?.first!["user_count"] {
//				
//					dispatch_async(dispatch_get_main_queue(), {
//						weakSelf.countLabel.text = "\(result)"
//					})
//				}
			
			
			
			test_database.query(sqlStatement: "select count(*) as user_count from tb_user", successClosure: { (result) in
				
				if let r = result.results?.first!["user_count"] {
					weakSelf.countLabel.text = "\(r)"
				}
				
				
				}, errorClosure: { (error) in
					
			})
//			}
			
			let end = NSDate()
			
			print("Took \(end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate)")
			
		}
		
//		try! SQLitePool.manager().initializeDatabase("app_test_database_1", andExtension: "db")
		
//		try! SQLitePool.manager().initializeDatabase("app_test_database", andExtension: "db")
//		
//		try! SQLitePool.manager().initializeDatabase("app_test_database", andExtension: "db")
//		
//		try! SQLitePool.manager().initializeDatabase("app_test_database", andExtension: "db")
		
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

