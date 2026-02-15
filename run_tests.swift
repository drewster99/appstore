#!/usr/bin/env swift

import Foundation

// Simple test runner for command-line testing
print("Running appstore CLI tests...")
print(String(repeating: "=", count: 60))

// Test 1: Basic search
print("\nTest 1: Basic search")
let test1 = Process()
test1.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test1.arguments = ["search", "test", "--limit", "1", "--output-mode", "oneline"]
try? test1.run()
test1.waitUntilExit()
print("Exit code: \(test1.terminationStatus)")

// Test 2: JSON output with metadata
print("\nTest 2: JSON output with metadata")
let test2 = Process()
test2.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test2.arguments = ["search", "spotify", "--limit", "1", "--output-mode", "json", "--output-file", "/tmp/test_output.json"]
try? test2.run()
test2.waitUntilExit()

if FileManager.default.fileExists(atPath: "/tmp/test_output.json") {
    print("✅ Output file created")

    // Check if it has metadata
    if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/test_output.json")),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       json["metadata"] != nil {
        print("✅ Metadata present")
    } else {
        print("❌ Metadata missing")
    }
} else {
    print("❌ Output file not created")
}

// Test 3: Input file reading
print("\nTest 3: Input file reading")
let test3 = Process()
test3.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test3.arguments = ["search", "ignored", "--input-file", "/tmp/test_output.json", "--output-mode", "oneline"]
try? test3.run()
test3.waitUntilExit()
print("Exit code: \(test3.terminationStatus)")

// Test 4: Lookup by ID
print("\nTest 4: Lookup by ID")
let test4 = Process()
test4.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test4.arguments = ["lookup", "284910350", "--output-mode", "oneline"]
try? test4.run()
test4.waitUntilExit()
print("Exit code: \(test4.terminationStatus)")

// Test 5: Top charts
print("\nTest 5: Top charts")
let test5 = Process()
test5.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test5.arguments = ["top", "free", "--limit", "2", "--output-mode", "oneline"]
try? test5.run()
test5.waitUntilExit()
print("Exit code: \(test5.terminationStatus)")

// Test 6: List command
print("\nTest 6: List genres")
let test6 = Process()
test6.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test6.arguments = ["list", "genres", "--output-mode", "json"]
let pipe = Pipe()
test6.standardOutput = pipe
try? test6.run()
test6.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    print("✅ Genres returned as JSON with \(json.count) entries")
} else {
    print("❌ Failed to parse genres JSON")
}

// Test 7: Invalid attribute error
print("\nTest 7: Invalid attribute error handling")
let test7 = Process()
test7.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test7.arguments = ["search", "test", "--attribute", "invalidattr", "--limit", "1"]
let errorPipe = Pipe()
test7.standardError = errorPipe
test7.standardOutput = errorPipe
try? test7.run()
test7.waitUntilExit()

let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: errorData, encoding: .utf8) {
    if output.contains("Invalid attribute") {
        print("✅ Proper error message for invalid attribute")
    } else {
        print("❌ Error message not informative")
    }
}

// Test 8: Environment variables
print("\nTest 8: Environment variables")
var env = ProcessInfo.processInfo.environment
env["APPSTORE_DEFAULT_LIMIT"] = "3"
env["APPSTORE_DEFAULT_STOREFRONT"] = "gb"

let test8 = Process()
test8.executableURL = URL(fileURLWithPath: "/Users/andrew/Library/Developer/Xcode/DerivedData/appstore-fmmbfpfjrlfolrfwhedbyltydogi/Build/Products/Debug/appstore")
test8.arguments = ["search", "music", "--output-mode", "json"]
test8.environment = env
let envPipe = Pipe()
test8.standardOutput = envPipe
try? test8.run()
test8.waitUntilExit()

let envData = envPipe.fileHandleForReading.readDataToEndOfFile()
if let json = try? JSONSerialization.jsonObject(with: envData) as? [String: Any],
   let metadata = json["metadata"] as? [String: Any],
   let params = metadata["parameters"] as? [String: Any] {
    let limit = params["limit"] as? Int ?? 0
    if limit == 3 {
        print("✅ Environment variable for limit applied")
    } else {
        print("❌ Environment variable for limit not applied (got \(limit))")
    }
}

// Cleanup
try? FileManager.default.removeItem(atPath: "/tmp/test_output.json")

print("\n" + String(repeating: "=", count: 60))
print("Tests completed!")