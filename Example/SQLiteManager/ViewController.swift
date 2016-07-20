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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
		try! SQLite.sharedManager.initializeDatabase("sqlite_manager_example_app_database", andExtension: "db")
		
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

