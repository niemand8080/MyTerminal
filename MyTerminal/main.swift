//
//  main.swift
//  MyTerminal
//
//  Created by Ben Seidler on 23.08.24.
//

import Foundation
import SQLite3

var currentPath = "~"
var currentDirectory = ""


// adds an children to directory
func addCildren() {

}

// delete item by id or name
func deleteChildren() {

}

// restores the last deleted Element
func restoreLastElement() {

}

// goes to the Directory
func openDir() {

}

// basicly cd ..
func goBack() {

}

// prints a list of all items in the current directory
func listCurrentDir() {

}

// gets an Item by the id of it...
func getItem() {

}

class DatabaseManager {
    private var db: OpaquePointer? // It's a type that is used for C API requests… so swift doesn't know the exact type… or something like this…
    private let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
    }

    func open() -> Bool {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        return true
    }

    func close() {
        sqlite3_close(db)
    }

    func executeSelectQuery(_ query: String) -> [[String: Any]]? {
        var statement: OpaquePointer?
        var results: [[String: Any]] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing query: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<sqlite3_column_count(statement) {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                if let value = getColumnValue(statement, index: i) {
                    row[columnName] = value
                }
            }
            results.append(row)
        }
        
        return results
    }

    private func getColumnValue(_ statement: OpaquePointer?, index: Int32) -> Any? {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(statement, index))
        case SQLITE_BLOB: 
            let dataSize = sqlite3_column_bytes(statement, index)
            let dataPointer = sqlite3_column_blob(statement, index)
            return Data(bytes: dataPointer!, count: Int(dataSize))
        case SQLITE_NULL:
            return nil
        default:
            return nil
        }
    }
    
    func executeQuery(_ query: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Query successfully executed.")
            } else {
                print("Error while executing query.")
            }
        } else {
            print("Error while preparing Query.")
        }

        sqlite3_finalize(statement)
    }
}

let dbPath =
    "/Users/ben/Library/Mobile Documents/com~apple~CloudDocs/programming/Xcode/Projects/Comandline/MyTerminal/MyTerminal/zaphod.sqlite"
let dbManager = DatabaseManager(dbPath: dbPath)

if dbManager.open() {
    if let results = dbManager.executeSelectQuery("SELECT * FROM hierachy") {
        for row in results {
            print(row)  // Each row is a dictionary with column names as keys
        }
    }
    dbManager.close()
} else {
    print("Failed to open database.")
}
