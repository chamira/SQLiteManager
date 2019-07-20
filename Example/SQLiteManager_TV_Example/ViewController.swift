//
//  ViewController.swift
//  SQLiteManager_TV_Example
//
//  Created by Chamira Fernando on 22/09/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import SQLiteManager
import sqlite3

class ViewController: UIViewController {

	var database: SQLite!

	@IBOutlet weak var queryTextView: UITextView!

	@IBOutlet weak var insertButton: UIButton!
	@IBOutlet weak var updateButton: UIButton!
	@IBOutlet weak var resultTextView: UITextView!
	@IBOutlet weak var countLabel: UILabel!
	@IBOutlet weak var statusCodeLabel: UILabel!
	@IBOutlet weak var asyncSegCnt: UISegmentedControl!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		queryTextView.text = insertQuery
		queryTextView.delegate = self
		queryTextView.keyboardType = .default
		queryTextView.becomeFirstResponder()

		do {

            database =  try SQLitePool.manager.initialize(database: "app_test_database_1", withExtension: "db")
			database.log = true

			//headerLabel.text = "Database '\(database.databaseName!)' is initialized successfully!\nWrite your SQL Query Below:"
			//headerLabel.textColor = UIColor.blackColor()
			//executeButton.enabled = true

		} catch let err as NSError {
			print(err)

			//headerLabel.text = "Error initializing database app_test_database_1.db \(e)"
			//headerLabel.textColor = UIColor.redColor()
			//executeButton.enabled = false
		}

	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	var insertQuery: String {
		let dob = Date(timeIntervalSince1970: 3600*24*3650)
		let query = """
        INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth)
        VALUES ('Joohn','Frenando', 'some_user_name', \(dob.timeIntervalSince1970))
        """
		return query
	}

	@IBAction func tapRunButton(_ sender: AnyObject) {
		runQuery()
	}

	func runQuery() {

		let query = queryTextView.text.trimmingCharacters(in: CharacterSet.whitespaces)

		unowned let refSelf = self

		let successClosure = {
            (result:(SQLiteSatusCode: Int32, affectedRowCount: Int, results: SQLiteDataArray?)) -> Void in

			refSelf.statusCodeLabel.text = "SQLite Status Code:\(result.SQLiteSatusCode == SQLITE_OK ? "SQLITE_OK" : "SQLITE_FAIL")"
			refSelf.countLabel.text = "Affected Row Count Count:\(result.affectedRowCount)"
			if let res = result.results {
				refSelf.resultTextView.text = "\(res)"
            } else {
                refSelf.resultTextView.text = nil
            }

		}
		let errorClosure = { (error: NSError) -> Void in
			refSelf.resultTextView.text = "Error:\n\(error)"
		}
		if (asyncSegCnt.selectedSegmentIndex == 0) {
			do {
				let result = try database.query(query)
				successClosure(result)
			} catch let err as NSError {
				errorClosure(err)
			}
		} else {

//            database.query(query, successClosure: { (res) in
//                successClosure(res)
//            }) { (error) in
//                errorClosure(error)
//            }
		}
	}

	@IBAction func tapCreateTVButton() {
		let query = """
CREATE TABLE IF NOT EXISTS
 tb_company(pkId INT PRIMARY KEY NOT NULL,name TEXT NOT NULL, age INT NOT NULL,address CHAR(50), salary REAL)
"""
		queryTextView.text = query

	}

	@IBAction func tapInsertButton() {
		queryTextView.text = insertQuery
	}

	@IBAction func tapUpdateButton() {
		let query = "UPDATE 'tb_user' SET first_name = 'John', last_name = 'Fernando' WHERE first_name = 'Joohn'"
		queryTextView.text = query
	}

	@IBAction func tapDeleteButton() {
		let query = "DELETE FROM 'tb_user' WHERE first_name = 'John'"
		queryTextView.text = query
	}

	@IBAction func tapSelectButton() {
		let query = "SELECT first_name, username, date_of_birth as dob from 'tb_user'"
		queryTextView.text = query
	}

}

extension ViewController: UITextViewDelegate {
	func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
		return true
	}

}
