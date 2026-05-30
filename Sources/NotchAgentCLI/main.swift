// ============================================================
// notchagent-cli — Command-line interface to the running app
// ============================================================
// Commands: status, list, toggle, approve, deny, collapse
// Communicates via the same Unix socket used by the bridge.
// ============================================================

import Foundation
import Darwin
import NotchAgentCore

private let executableName = URL(fileURLWithPath: CommandLine.arguments.first ?? "notchagent")
    .lastPathComponent

private func printUsage() {
    print("""
    Usage: \(executableName.isEmpty ? "notchagent" : executableName) <command>

    Commands:
      status      Show current surface, active sessions, and pending items
      list        List all sessions with source, project, status, and cost
      toggle      Toggle panel between collapsed and session-list
      approve     Approve the first pending permission
      deny        Deny the first pending permission
      collapse    Collapse the panel
      completion  Print shell completion script (bash/zsh)
      help        Show this help message

    Environment:
      NOTCHAGENT_SOCKET_PATH  Override the default socket path
    """)
}

private func printCompletion(shell: String) {
    let bashScript = """
    # Bash completion for notchagent
    _notchagent() {
        local cur prev opts
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        opts="status list toggle approve deny collapse completion help"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    }
    complete -F _notchagent notchagent notchagent-cli
    """

    let zshScript = """
    #compdef notchagent notchagent-cli
    _notchagent() {
        local -a commands
        commands=(
            'status:Show current surface and active sessions'
            'list:List all sessions'
            'toggle:Toggle panel visibility'
            'approve:Approve pending permission'
            'deny:Deny pending permission'
            'collapse:Collapse the panel'
            'completion:Print shell completion script'
            'help:Show help'
        )
        _describe -t commands 'notchagent commands' commands
    }
    compdef _notchagent notchagent notchagent-cli
    """

    let lower = shell.lowercased()
    if lower.contains("zsh") {
        print(zshScript)
    } else {
        print(bashScript)
    }
}

private func sendCommand(_ command: String) -> Data? {
    let socketPath = SocketPath.path
    let sock = socket(AF_UNIX, SOCK_STREAM, 0)
    guard sock >= 0 else { return nil }

    var on: Int32 = 1
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let sunPathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
    guard socketPath.utf8.count < sunPathCapacity else {
        close(sock)
        return nil
    }
    withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
        socketPath.withCString {
            _ = strncpy(ptr, $0, sunPathCapacity)
            ptr.advanced(by: sunPathCapacity - 1).pointee = 0
        }
    }

    let origFlags = fcntl(sock, F_GETFL)
    _ = fcntl(sock, F_SETFL, origFlags | O_NONBLOCK)

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(sock, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    if result != 0 && errno != EINPROGRESS {
        close(sock)
        return nil
    }

    if result != 0 {
        var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
        let ready = poll(&pfd, 1, 2000)
        if ready <= 0 {
            close(sock)
            return nil
        }
        var sockErr: Int32 = 0
        var errLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &sockErr, &errLen)
        if sockErr != 0 {
            close(sock)
            return nil
        }
    }

    _ = fcntl(sock, F_SETFL, origFlags)

    let envelope: [String: Any] = [
        "_notchagent_command": command,
        "session_id": "cli",
        "hook_event_name": "Command"
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: envelope) else {
        close(sock)
        return nil
    }

    dataSend(sock, data: body)
    shutdown(sock, SHUT_WR)

    var response = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = recv(sock, &buf, buf.count, 0)
        if n < 0 {
            if errno == EINTR { continue }
            break
        }
        if n == 0 { break }
        response.append(contentsOf: buf[..<n])
    }
    close(sock)
    return response
}

private func dataSend(_ sock: Int32, data: Data) {
    data.withUnsafeBytes { buf in
        guard let base = buf.baseAddress else { return }
        var sent = 0
        while sent < buf.count {
            let n = send(sock, base + sent, buf.count - sent, 0)
            if n < 0 {
                if errno == EINTR { continue }
                break
            }
            if n == 0 { break }
            sent += n
        }
    }
}

// MARK: - Main

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : ""

switch command {
case "status", "list", "toggle", "approve", "deny", "collapse":
    guard let data = sendCommand(command) else {
        fputs("Error: Could not connect to NotchAgent. Is it running?\n", stderr)
        exit(1)
    }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let error = json["error"] as? String {
            print("Error: \(error)")
            exit(1)
        }
        // Pretty-print JSON response
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            print(String(data: pretty, encoding: .utf8) ?? "{}")
        } else {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    } else {
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
case "completion":
    let shell = args.count > 2 ? args[2] : (ProcessInfo.processInfo.environment["SHELL"] ?? "bash")
    printCompletion(shell: shell)
case "-h", "--help", "help":
    printUsage()
default:
    printUsage()
    exit(1)
}
