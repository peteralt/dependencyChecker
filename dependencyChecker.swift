import Foundation

// ANSI color codes
let red = "\u{001B}[0;31m"
let green = "\u{001B}[0;32m"
let yellow = "\u{001B}[0;33m"
let reset = "\u{001B}[0;0m"

// Function to test a URL and return status with colored output
func checkURL(_ urlString: String) {
    guard let url = URL(string: urlString) else {
        print("\(red)Invalid URL: \(urlString)\(reset)")
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
