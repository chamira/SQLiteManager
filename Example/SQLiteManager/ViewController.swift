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
    var database:SQLite!
    
    override func viewDidLoad() {
        super.viewDidLoad()
		
		executeButton.isEnabled = false
        do {
            
            database =  try SQLitePool.manager().initialize(database: "app_test_database_1", withExtension: "db")
            database.log = true
            
            headerLabel.text = "Database '\(database.databaseName!)' is initialized successfully!\nWrite your SQL Query Below:"
            headerLabel.textColor = UIColor.black
            executeButton.isEnabled = true
            
        } catch let e as NSError {
            headerLabel.text = "Error initializing database app_test_database_1.db \(e)"

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
    
        let q = queryTextView.text.trimmingCharacters(in: CharacterSet.whitespaces)
        
        unowned let refSelf = self
        
        let successClosure = { (result:(SQLiteSatusCode:Int32,affectedRowCount:Int,results:SQLiteDataArray?))->() in
          
            refSelf.statusCodeLabel.text = "SQLite Status Code:\(result.SQLiteSatusCode == SQLITE_OK ? "SQLITE_OK" : "SQLITE_FAIL")"
            refSelf.countLabel.text = "Affected Row Count Count:\(result.affectedRowCount)"
            if let r = result.results {
                refSelf.resultTextView.text = "\(r)"
            }

        }
        
        let errorClosure = { (error:NSError) ->() in
            refSelf.resultTextView.text = "Error:\n\(error)"
        }
        
        if (!asyncButton.isOn) {
            
            do {
                let result = try database.query(q)
                successClosure(result)
            } catch let e as NSError {
                errorClosure(e)
            }
            
        } else {
           
            database.query(q, successClosure: { (result) in
                successClosure(result)
            }, errorClosure: { (error) in
                errorClosure(error)
            })
            
        }
    }
    
    @IBAction func tapCreateButton(_ sender: AnyObject) {
        let q = "CREATE TABLE IF NOT EXISTS tb_company(pkId INT PRIMARY KEY NOT NULL,name TEXT NOT NULL, age INT NOT NULL,address CHAR(50), salary REAL)"
        queryTextView.text = q
        
    }
    
    @IBAction func tapInsertButton(_ sender: AnyObject) {
        let dob = Date(timeIntervalSince1970: 3600*24*3650)
        let q = "INSERT INTO 'tb_user' (first_name, last_name, username, date_of_birth) VALUES ('Joohn','Frenando', 'some_user_name', \(dob.timeIntervalSince1970))"
        queryTextView.text = q
    }
    
    @IBAction func tapUpdateButton(_ sender: AnyObject) {
        let q = "UPDATE 'tb_user' SET first_name = 'John', last_name = 'Fernando' WHERE first_name = 'Joohn'"
        queryTextView.text = q
    }

    @IBAction func tapDeleteButton(_ sender: AnyObject) {
        let q = "DELETE FROM 'tb_user' WHERE first_name = 'John'"
        queryTextView.text = q
    }
    
    @IBAction func tapSelectButton(_ sender: AnyObject) {
        let q = "SELECT first_name, username, date_of_birth as dob from 'tb_user'"
        queryTextView.text = q
    }
    
}

