import Foundation
import Darwin

public enum SocketPath {
    public static var path: String {
        if let env = ProcessInfo.processInfo.environment["NOTCHAGENT_SOCKET_PATH"] {
            return env
        }
        return "/tmp/notchagent-\(getuid()).sock"
    }
}
