import Foundation

// ANSI color codes
let red = "\u{001B}[0;31m"
let green = "\u{001B}[0;32m"
let yellow = "\u{001B}[0;33m"
let reset = "\u{001B}[0;0m"

// Function to run shell commands
func runShellCommand(_ command: String) -> (output: String?, exitCode: Int32) {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh") // You can adjust this for your shell

    do {
        try task.run()
    } catch {
        return (nil, task.terminationStatus)
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)

    task.waitUntilExit()
    return (output, task.terminationStatus)
}

// Function to test an HTTPS URL
func checkHTTPURL(_ urlString: String) {
    guard let url = URL(string: urlString) else {
        print("\(red)Invalid HTTPS URL: \(urlString)\(reset)")
        return
    }

    let semaphore = DispatchSemaphore(value: 0)
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"  // We only want to check the status

    let task = URLSession.shared.dataTask(with: request) { _, response, error in
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                print("\(green)\(urlString): Accessible (Status: \(httpResponse.statusCode))\(reset)")
            } else {
                print("\(red)\(urlString): Error (Status: \(httpResponse.statusCode))\(reset)")
            }
        } else if let error = error {
            print("\(red)\(urlString): Error \(error.localizedDescription)\(reset)")
        } else {
            print("\(yellow)\(urlString): Unknown error\(reset)")
        }
        semaphore.signal()
    }

    task.resume()
    semaphore.wait()
}

// Function to test an SSH URL
func checkSSHURL(_ urlString: String) {
    // Using git ls-remote to check if the SSH URL is accessible
    let command = "git ls-remote \(urlString)"
    let result = runShellCommand(command)

    if result.exitCode == 0 {
        print("\(green)\(urlString): Accessible via SSH\(reset)")
    } else {
        print("\(red)\(urlString): Error accessing via SSH (Exit Code: \(result.exitCode))\(reset)")
    }
}

// Function to check URL, and determine whether it's HTTP(S) or SSH
func checkURL(_ urlString: String) {
    if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
        checkHTTPURL(urlString)
    } else if urlString.hasPrefix("git@") || urlString.hasPrefix("ssh://") {
        checkSSHURL(urlString)
    } else {
        print("\(yellow)Unsupported URL scheme: \(urlString)\(reset)")
    }
}

// Check if file path is provided as an argument
guard CommandLine.arguments.count > 1 else {
    print("\(red)Error: No file path provided. Usage: swift checkDependencies.swift <path_to_package.resolved>\(reset)")
    exit(1)
}

// Get the file path from the command line argument
let filePath = CommandLine.arguments[1]
let fileURL = URL(fileURLWithPath: filePath)

do {
    let data = try Data(contentsOf: fileURL)
    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
       let pins = json["pins"] as? [[String: Any]] {
        
        for pin in pins {
            if let location = pin["location"] as? String {
                checkURL(location)
            }
        }
    } else {
        print("\(red)Error: Invalid JSON structure\(reset)")
    }
} catch {
    print("\(red)Error reading file: \(error.localizedDescription)\(reset)")
}
