import Foundation

/// Tracks per-source performance metrics for the leaderboard.
public struct SourceMetrics: Codable, Equatable, Identifiable {
    public let id: String  // source identifier
    public var sessionCount: Int
    public var completedCount: Int
    public var totalDurationSeconds: TimeInterval
    public var totalToolCalls: Int
    public var totalApprovals: Int
    public var deniedApprovals: Int
    public var lastUpdated: Date

    public var averageDuration: TimeInterval {
        guard sessionCount > 0 else { return 0 }
        return totalDurationSeconds / Double(sessionCount)
    }

    public var completionRate: Double {
        guard sessionCount > 0 else { return 0 }
        return Double(completedCount) / Double(sessionCount)
    }

    public var approvalRate: Double {
        let total = totalApprovals + deniedApprovals
        guard total > 0 else { return 1.0 }
        return Double(totalApprovals) / Double(total)
    }

    public init(id: String) {
        self.id = id
        self.sessionCount = 0
        self.completedCount = 0
        self.totalDurationSeconds = 0
        self.totalToolCalls = 0
        self.totalApprovals = 0
        self.deniedApprovals = 0
        self.lastUpdated = Date()
    }
}

/// Lightweight persistent tracker for agent performance leaderboard.
public enum PerformanceTracker {
    private static let storageKey = "notchagent_performance_v1"
    private static let dailyStorageKey = "notchagent_performance_daily_v1"

    /// Load all-time source metrics from UserDefaults.
    public static func loadAllTime() -> [String: SourceMetrics] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: SourceMetrics].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// Save all-time source metrics.
    public static func saveAllTime(_ metrics: [String: SourceMetrics]) {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Record a completed session.
    public static func recordSession(
        source: String,
        duration: TimeInterval,
        toolCalls: Int,
        completed: Bool,
        approvals: Int = 0,
        denied: Int = 0
    ) {
        var metrics = loadAllTime()
        var entry = metrics[source] ?? SourceMetrics(id: source)
        entry.sessionCount += 1
        entry.totalDurationSeconds += max(0, duration)
        entry.totalToolCalls += toolCalls
        entry.totalApprovals += approvals
        entry.deniedApprovals += denied
        if completed {
            entry.completedCount += 1
        }
        entry.lastUpdated = Date()
        metrics[source] = entry
        saveAllTime(metrics)
    }

    /// Record a single tool call.
    public static func recordToolCall(source: String) {
        var metrics = loadAllTime()
        var entry = metrics[source] ?? SourceMetrics(id: source)
        entry.totalToolCalls += 1
        entry.lastUpdated = Date()
        metrics[source] = entry
        saveAllTime(metrics)
    }

    /// Record an approval decision.
    public static func recordApproval(source: String, allowed: Bool) {
        var metrics = loadAllTime()
        var entry = metrics[source] ?? SourceMetrics(id: source)
        if allowed {
            entry.totalApprovals += 1
        } else {
            entry.deniedApprovals += 1
        }
        entry.lastUpdated = Date()
        metrics[source] = entry
        saveAllTime(metrics)
    }

    /// Reset all tracked metrics.
    public static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: dailyStorageKey)
    }

    /// Sorted leaderboard entries (best completion rate, then most sessions).
    public static func leaderboard() -> [SourceMetrics] {
        loadAllTime().values.sorted { a, b in
            if a.completionRate != b.completionRate {
                return a.completionRate > b.completionRate
            }
            return a.sessionCount > b.sessionCount
        }
    }
}
