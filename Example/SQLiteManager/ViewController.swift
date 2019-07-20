//
//  ViewController.swift
//  SQLiteManager
//
//  Created by Chamira Fernando on 07/19/2016.
//  Copyright (c) 2016 Chamira Fernando. All rights reserved.
//

import UIKit
import SQLiteManager
import sqlite3

/// These examples are to show how to use SQLITEManager lib,
/// It is up to you to have application architecture based on your needs.

class ViewController: UIViewController {

    @IBOutlet weak var headerLabel: UILabel!
	@IBOutlet weak var countLabel: UILabel!

    @IBOutlet weak var queryTextView: UITextView!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var executeButton: UIButton!
    @IBOutlet weak var asyncButton: UISwitch!
    var database: SQLite!

    override func viewDidLoad() {
        super.viewDidLoad()

		executeButton.isEnabled = false
        do {
            database =  try SQLitePool.manager.initialize(database: "app_test_database_1", withExtension: "db")
            database.log = true
            headerLabel.text = """
Database '\(database.databaseName)' is initialized successfully!\nWrite your SQL Query Below:
"""
            headerLabel.textColor = UIColor.black
            executeButton.isEnabled = true
        } catch let err as NSError {
            headerLabel.text = "Error initializing database app_test_database_1.db \(err)"

            headerLabel.textColor = UIColor.red
            executeButton.isEnabled = false
        }
    }

	override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /**
     Executing SQL query
     
     - parameter sender: button
     */
    @IBAction func tapExecuteQueryButton(_ sender: AnyObject) {
        let query = queryTextView.text.trimmingCharacters(in: CharacterSet.whitespaces)
        
        let successClosure:(SQLiteQueryResult)->() = { [weak self]
            (arg: (SQLiteSatusCode: Int32, affectedRowCount: Int, results: SQLiteDataArray?)) -> Void in
            let (SQLiteSatusCode, affectedRowCount, results) = arg
            self?.statusCodeLabel.text =
            "SQLite Status Code:\(SQLiteSatusCode == SQLITE_OK ? "SQLITE_OK" : "SQLITE_FAIL")"
            self?.countLabel.text = "Affected Row Count Count:\(affectedRowCount)"
            if let res = results {
                self?.resultTextView.text = "\(res)"
            }
        }
        let errorClosure = { [weak self](error: Error) -> Void in
            self?.resultTextView.text = "Error:\n\(error)"
        }

        if !asyncButton.isOn {
            do {
                let result = try database.query(query)
                successClosure(result)
            } catch {
                errorClosure(error)
            }
        } else {
            database.query(query, successClosure: { (result) in
                successClosure(result)
            }, errorClosure: { (error) in
                errorClosure(error)
            })
        }
    }

    @IBAction func tapCreateButton(_ sender: AnyObject) {
        let query = """
CREATE TABLE IF NOT EXISTS
tb_company(pkId INT PRIMARY KEY NOT NULL,name TEXT NOT NULL, age INT NOT NULL,address CHAR(50), salary REAL)
"""
        queryTextView.text = query

    }

    @IBAction func tapInsertButton(_ sender: AnyObject) {
        let dob = Date(timeIntervalSince1970: 3600*24*3650)
        let query = """
        INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth)
        VALUES ('Joohn','Frenando', 'some_user_name', \(dob.timeIntervalSince1970))
        """
        queryTextView.text = query
    }

    @IBAction func tapUpdateButton(_ sender: AnyObject) {
        let query = "UPDATE 'tb_user' SET first_name = 'John', last_name = 'Fernando' WHERE first_name = 'Joohn'"
        queryTextView.text = query
    }

    @IBAction func tapDeleteButton(_ sender: AnyObject) {
        let query = "DELETE FROM 'tb_user' WHERE first_name = 'John'"
        queryTextView.text = query
    }

    @IBAction func tapSelectButton(_ sender: AnyObject) {
        let query = "SELECT first_name, username, date_of_birth as dob from 'tb_user'"
        queryTextView.text = query
    }

}
