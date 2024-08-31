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
    case cmd, dir, undefined
}

extension String {
    func containsChars(_ chars: String = "") -> [Character]? {
        let charackters = chars == "" ? DatabaseManager.forbiddenCharacters.joined(separator: "") : chars
        var characktersIncluded = ""
        var result: [Character] = []
        
        for char in charackters {
            let str = "\(char)"
            let contains = str.contains(where: self.contains)
            characktersIncluded += contains ? str : ""
        }
        
        for char in characktersIncluded {
            result.append(char as Character)
        }
        
        return result == [] ? nil : result
    }
    
    /// Replaces all occurrences of specified characters with a given string.
    mutating func replaceAll(chars: String, with: String) {
        self = self.replacedAll(chars: chars, with: with)
    }

    /// Returns a new string with all occurrences of specified characters replaced with a given string.
    func replacedAll(chars: String, with: String) -> String {
        var filterd = self
        for char in chars {
            var containsChar = filterd.contains(char)
            while containsChar {
                filterd.replaceFirstExpression(of: String(char), with: with)
                containsChar = filterd.contains(char)
            }
        }
        return filterd
    }

    /// Removes leading and trailing whitespace and newlines from the string.
    mutating func trim() {
        self = self.trimed()
    }

    /// Returns a new string with leading and trailing whitespace and newlines removed.
    func trimed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes characters from the beginning of the string up to and including the specified substring.
    mutating func removedUntil(_ str: String) {
        self = self.removeUntil(str)
    }

    /// Returns a new string with characters removed from the beginning up to and including the specified substring.
    func removeUntil(_ str: String) -> String {
        var components = [Character]()

        for char in self { components.append(char) }

        var current = ""
        var result = ""

        for char in components {
            if !current.contains(str) {
                current.append(char)
            } else {
                break
            }
        }

        for _ in 1...current.count { components.removeFirst() }
        for char in components { result.append(char) }

        return result
    }

    /// Replaces the first occurrence of a specified pattern with a replacement string.
    mutating func replaceFirstExpression(of pattern: String, with replacement: String) {
        self = self.replacedFirstExpression(of: pattern, with: replacement)
    }

    /// Returns a new string with the first occurrence of a specified pattern replaced with a replacement string.
    func replacedFirstExpression(
        of pattern: String,
        with replacement: Any
    ) -> String {
        let replace: String = "\(replacement)"
        if let range = self.range(of: pattern) {
            return self.replacingCharacters(in: range, with: replace)
        } else {
            return self
        }
    }

    /// Extracts a substring between specified start and end strings.
    func cut(start: String, end: String, ceepStartEnd: Bool = false) -> String? {
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

        if result.isEmpty { return nil }

        if ceepStartEnd { return result } else { return result.replacing(start, with: "").replacing(end, with: "") }
    }
}

extension Collection {
    /// Checkst if the collection is not Empty
    func isNotEmpty() -> Bool { !self.isEmpty }
}

/// Class to store SQL rows
class HierarchyRow {
    let name: String?
    let deleted: String?
    let type: String?
    let execution: String?
    let parentName: String?
    let uid: Int?
    let favorite: Int?
    let parent: Int?

    init(
        name: String?,
        deleted: String?,
        type: String?,
        execution: String?,
        parentName: String?,
        uid: Int?,
        favorite: Int?,
        parent: Int?
    ) {
        self.name = name
        self.deleted = deleted
        self.type = type
        self.execution = execution
        self.parentName = parentName
        self.uid = uid
        self.favorite = favorite
        self.parent = parent
    }

    func printMs() {
        let fav = favorite == 1 ? "\"" : ""
        if type == "command" {
            if uid != nil || name != nil {
                print("\(uid ?? 0): \(fav)\(name ?? "UNKNOWN")\(fav) - '\(execution ?? "UNKNOWN")'")
            } else {
                print("ERROR: Something went wrong loading this command")
            }
        } else {
            if uid != nil || name != nil {
                print("\(uid ?? 0): \(fav)\(name ?? "UNKNOWN")\(fav) >")
            } else {
                print("ERROR: Something went wrong loading this directory")
            }
        }
    }
}

class DatabaseManager {
    private var db: OpaquePointer?  // It's a type that is used for C API requests… so swift doesn't know the exact type… or something like that…
    private let dbPath: String
    static let forbiddenCharacters: [String] = ["/", ":"]
    let homeDirectory = "~"
    var currentDirectory = "~"
    var currentParentUid: Int {
        executeSelectHierarchy(query: "SELECT parent FROM hierarchy WHERE name = ?", args: [currentDirectory])?[0]
            .parent ?? 0
    }
    var currentUid: Int {
        executeSelectHierarchy(query: "SELECT uid FROM hierarchy WHERE name = ?", args: [currentDirectory])?[0].uid ?? 0
    }
    var currentPath: String { getPath() }

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
        print("Closed MyTerminal!")
    }

    func executeSelectHierarchy(query: String, args: [Any] = []) -> [HierarchyRow]? {
        var finalQuery = query
        if args.isNotEmpty() {
            for arg in args {
                finalQuery = finalQuery.replacedFirstExpression(of: "?", with: "'\(arg)'")
            }
        }

        var statement: OpaquePointer?
        var results: [HierarchyRow] = []

        guard sqlite3_prepare_v2(db, finalQuery, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing query: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        defer {
            sqlite3_finalize(statement)
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [
                "name": "", "deleted": "", "parent": 0, "type": "", "favorite": 0, "execution": "", "uid": 0,
                "parentName": "",
            ]
            for i in 0..<sqlite3_column_count(statement) {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                if let value = getColumnValue(statement, index: i) {
                    row[columnName] = value
                }
            }
            results
                .append(
                    HierarchyRow(
                        name: row["name"] as? String,
                        deleted: row["deleted"] as? String,
                        type: row["type"] as? String,
                        execution: row["execution"] as? String,
                        parentName: row["parentName"] as? String,
                        uid: row["uid"] as? Int,
                        favorite: row["favorite"] as? Int,
                        parent: row["parent"] as? Int
                    )
                )
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

    func executeQuery(_ query: String, succes message: String = "Query successfully executed.") {
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print(message)
            } else {
                print("Error while executing query.")
            }
        } else {
            print("Error while preparing Query.")
        }

        sqlite3_finalize(statement)
    }

    /// Handles the execution of commands
    func execute(command: String) {
        switch command {
        case "!close":
            close()
        case var cmd where cmd.starts(with: "!add"):  // !add (to:[wished dir name];) [type] [name] "[execution]" (execution is only requierd if you create a cmd)
            do {
                if cmd.count == 4 {
                    breakWith(
                        message:
                            "To add an element to the current or wished `Directory` run: \n!add (to:[wished dir name];) [dir|cmd] [name] \"[execution]\" (execution is only for commands)."
                    )
                    return
                }

                cmd.removeFirst(5)
                let cmdCopy = cmd
                let targetDirUid: Int

                if let dirName = cmd.cut(start: "to:", end: ";") {
                    cmd.removeFirst(4 + dirName.count)
                    if let response = executeSelectHierarchy(
                        query: "SELECT uid FROM hierarchy WHERE name = ?",
                        args: [dirName]
                    ) {
                        targetDirUid = response[0].uid ?? currentUid
                    } else {
                        breakWith(message: "Please enter a vailid `Target Directory Name`.")
                        return
                    }
                } else {
                    targetDirUid = currentUid
                }

                let args = cmd.trimed().components(separatedBy: " ")
                let type: Types
                let name: String
                let execution: String

                if args.count < 2 {
                    breakWith(message: "Some arguments are missing, please try again.")
                    return
                }

                type = args[0] == "dir" ? .dir : args[0] == "cmd" ? .cmd : .undefined
                name = args[1]
                execution = type == .dir ? "" : cmdCopy.cut(start: "\"", end: "\"") ?? ""

                if type == .undefined {
                    breakWith(message: "Please enter a vailid type: `\(args[0])`")
                    return
                }

                if type == .cmd && execution == "" {
                    breakWith(message: "Please enter a vailid execution.")
                    return
                }

                let success = addChildren(to: targetDirUid, name: name, type: type, execution: execution)
                if success {
                    runMyTerminal()
                }
            }
        case var cmd where cmd.starts(with: "!path"):  // !path [name]
            do {
                let path: String
                if cmd.trimed().count == 5 {
                    path = getPath()
                } else {
                    cmd.removeFirst(5)
                    path = getPath(from: cmd.trimed())
                }
                breakWith(message: path)
            }
        case var path where path.starts(with: "!cd"):
            path.removeFirst(3)
            path.trim()
            
            if path == homeDirectory {
                currentDirectory = homeDirectory
            } else {
                changeDirectory(path: path)
            }
            
            runMyTerminal()
        case var cmd where cmd.starts(with: "!ls"):
            cmd.removeFirst(3)
            printChildrenFromDir()
        default:
            breakWith(message: "This command is not defined: \(command)")
        }
    }

    /// Prints the givenn Message and run's runMyTerminal()
    func breakWith(message: String) {
        print(message)
        runMyTerminal()
    }

    /// get's the path to the given element or of the current dir
    func getPath(from element: String = "") -> String {
        var currentDirName = element == "" ? currentDirectory : element
        var path = [currentDirName]
        var error = false

        while currentDirName != "~" && !error {
            let parentName: String = executeSelectHierarchy(query: "SELECT parent.name AS parentName FROM hierarchy current LEFT JOIN hierarchy parent ON parent.uid = current.parent WHERE current.name = ?", args: [currentDirName])?.first?.parentName ?? "UNKNOWN"
            
            if parentName == "UNKNOWN" { error = true }
            
            path.insert(parentName, at: 0)
            currentDirName = parentName
        }
        
        if error {
            return "Path not found"
        }

        return path.joined(separator: "/")
    }

    /// adds an children to current or wished directory
    func addChildren(to dir: Int = 0, name: String, type: Types, execution: String) -> Bool {
        let targetDir = dir == 0 ? currentUid : dir
        
        if let chars = name.containsChars() {
            breakWith(message: "Please don't use thes charackters: \"\(chars.map(\.description).joined(separator: ", "))\"")
            return false
        }
        
        print(execution.replacedAll(chars: "�", with: ""))
        if type == .cmd {
            executeQuery(
                "INSERT INTO hierarchy (name, parent, favorite, type, execution) VALUES ('\(name)',\(targetDir),0,'command','\(execution.replacedAll(chars: "�", with: ""))')",
                succes: "Command successfully added"
            )
        } else {
            executeQuery(
                "INSERT INTO hierarchy (name, parent, favorite, type) VALUES ('\(name)',\(targetDir),0,'directory')",
                succes: "Directory successfully added"
            )
        }
        
        return true
    }

    /// prints the children from the given dir or the current
    func printChildrenFromDir(_ name: String = "") {
        let dirUid: Int
        if name != "" {
            dirUid =
                executeSelectHierarchy(query: "SELECT uid FROM hierarchy WHERE name = ?", args: [name])?[0].uid ?? 0
        } else {
            dirUid = currentUid
        }

        if let children = executeSelectHierarchy(query: "SELECT * FROM hierarchy WHERE parent = ?", args: [dirUid]) {
            for child in children {
                child.printMs()
            }
        }
    }

    /// goes to the give path
    func changeDirectory(path: String) {
        var components = path.split(separator: "/")
        let first = components.removeFirst()
        
        if first == ".." {
            
        }
        
        print(components)
    }

    /// delete item by id or name
    func deleteChildren() {

    }

    /// restores the last deleted Element
    func restoreLastElement() {

    }

    /// basicly cd ..
    func goBack() {

    }

    /// prints a list of all items in the current directory
    func listCurrentDir() {

    }

    /// gets an Item by the id of it...
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
    } else {
        print("Failed to open database.")
    }
}

print(
    """
    Welcome to MyTerminal
    if you need help type `!help`
    """)

runMyTerminal()
