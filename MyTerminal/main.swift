//
//  main.swift
//  MyTerminal
//
//  Created by Ben Seidler on 23.08.24.
//

import Foundation
import SQLite3

let response = readLine()

enum Types {
    case cmd, dir
}

extension String {
    func cut(start: String, end: String) -> String {
        var startComponents = [Character]()
        var endComponents = [Character]()
        
        for char in start {
            startComponents.append(char)
        }
                
        for char in end {
            endComponents.append(char)
        }
        
        var result = ""
        var current = ""
                
        for char in self {
            if current.count < startComponents.count && !result.starts(with: start) {
                if char == startComponents[current.count] {
                    current.append(char)
                } else {
                    current = ""
                }
            } else if current == start {
                result = current
                current = ""
            }
            
            if result.starts(with: start) {
                if current != end {
                    if char == endComponents[current.count] {
                        current.append(char)
                    } else {
                        current = ""
                    }
                    result.append(char)
                } else {
                    break
                }
            }
        }
        
        return result.replacing(start, with: "").replacing(end, with: "")
    }
}

class DatabaseManager {
    private var db: OpaquePointer?  // It's a type that is used for C API requests… so swift doesn't know the exact type… or something like that…
    private let dbPath: String
    var currentPath = "~"
    var currentDirectory = "~"
    var currentParentId = 1

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
        print("Closed MyTerminal!")
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
            return "NULL"
        default:
            return "NULL"
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
    
    func execute(command: String) {
        switch command {
        case "!close":
            close()
        case var cmd where cmd.starts(with: "!add "):
            cmd.removeFirst(5)
            let args = cmd.components(separatedBy: " ")
            let type: Types = args[0] == "dir" ? .dir : .cmd
            let name = args[1]
            let execution = type == .dir ? "" : cmd.cut(start: "\"", end: "\"")
            addChildren(name: name, type: type, execution: execution)
        default:
            print("This command is not defined.")
            runMyTerminal()
        }
    }

    // adds an children to directory
    func addChildren(name: String, type: Types, execution: String) {
        if type == .cmd {
            executeQuery(
                "INSERT INTO hierachy (name, parent, favorite, type, execution) VALUES (\(name),\(currentParentId),0,command,\(execution))"
            )
        } else {
            executeQuery(
                "INSERT INTO hierachy (name, parent, favorite, type) VALUES (\(name),\(currentParentId),0,directory)"
            )
        }
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
}

let dbPath =
    "/Users/ben/Library/Mobile Documents/com~apple~CloudDocs/programming/Xcode/Projects/Comandline/MyTerminal/MyTerminal/zaphod.sqlite"
let dbManager = DatabaseManager(dbPath: dbPath)

func runMyTerminal() {
    if dbManager.open() {
        let command = readLine() ?? "!"
        
        if command != "" {
            dbManager.execute(command: command)
        } else {
            runMyTerminal()
        }
        
        //    if let results = dbManager.executeSelectQuery("SELECT \(select) FROM hierachy") {
        //        for row in results {
        //            print(row)  // Each row is a dictionary with column names as keys
        //        }
        //    }
    } else {
        print("Failed to open database.")
    }
}

print("""

Welcome to MyTerminal
if you need a guide type !guide

""")

runMyTerminal()
