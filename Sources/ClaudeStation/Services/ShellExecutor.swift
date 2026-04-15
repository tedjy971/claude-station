import Foundation

enum ShellExecutor {

    /// Run a command with proper argument separation (no shell interpretation).
    /// Preferred over `shell()` — immune to injection.
    static func run(executable: String = "/usr/bin/env", _ args: String...) async -> String {
        await runArgs(executable: executable, args: Array(args))
    }

    /// Run with an array of arguments.
    static func runArgs(executable: String = "/usr/bin/env", args: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: "")
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
        }
    }
}
