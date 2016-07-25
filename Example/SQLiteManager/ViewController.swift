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
		
		let database =  try! SQLitePool.manager().initializeDatabase("app_test_database_1", andExtension: "db")
		
		database.log = true
		
		let select = try! database.query(sqlStatement: "SELECT first_name, username, date_of_birth as dob from 'tb_user'")
		print(select.results)
		
		let result = try! database.query(sqlStatement: "select count(*) as user_count from tb_user")
		if let r = result.results?.first!["user_count"] {
			self.countLabel.text = "\(r)"
		}
		
	
		unowned let weakSelf = self
		database.query(sqlStatement: "select count(*) as user_count from tb_user", successClosure: { (result) in
			
				if let r = result.results?.first!["user_count"] {
					weakSelf.countLabel.text = "\(r)"
				}
			
			}, errorClosure: { (error) in
				print("Database Error",error)
			})
		
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

