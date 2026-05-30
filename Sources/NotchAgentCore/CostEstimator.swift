import Foundation

/// Estimates API usage costs for AI coding sessions based on model
/// pricing tables and observed tool-call activity.
public enum CostEstimator {
    /// Pricing per 1M tokens (input / output) in USD.
    /// These are approximate list prices; actual rates vary by tier.
    private static let pricingTable: [String: (input: Double, output: Double)] = [
        // Anthropic
        "claude-opus-4": (15.00, 75.00),
        "claude-sonnet-4": (3.00, 15.00),
        "claude-sonnet-4-5": (3.00, 15.00),
        "claude-opus": (15.00, 75.00),
        "claude-sonnet": (3.00, 15.00),
        "claude-3-5-sonnet": (3.00, 15.00),
        "claude-3-5-haiku": (0.80, 4.00),
        "claude-haiku": (0.80, 4.00),
        "claude-3-haiku": (0.80, 4.00),
        // OpenAI
        "gpt-4o": (2.50, 10.00),
        "gpt-4o-mini": (0.15, 0.60),
        "gpt-4": (30.00, 60.00),
        "gpt-4-turbo": (10.00, 30.00),
        "gpt-3.5-turbo": (0.50, 1.50),
        "codex": (2.50, 10.00),
        // Google
        "gemini-2.5-pro": (1.25, 10.00),
        "gemini-2.5-flash": (0.15, 0.60),
        "gemini-1.5-pro": (1.25, 10.00),
        "gemini-1.5-flash": (0.15, 0.60),
        "gemini-pro": (1.25, 10.00),
        // Cursor / Others
        "cursor": (2.50, 10.00),
        "cursor-fast": (1.00, 5.00),
        "qwen": (1.00, 5.00),
        "qwen2.5": (1.00, 5.00),
        "kimi": (2.00, 8.00),
        "kimi-k2": (2.00, 8.00),
    ]

    /// Heuristic tokens per tool call (input prompt + tool result).
    private static let tokensPerToolCall: Double = 3_500
    /// Heuristic tokens for a typical user prompt.
    private static let tokensPerPrompt: Double = 500
    /// Heuristic tokens for a typical assistant reply.
    private static let tokensPerReply: Double = 1_200

    /// Look up pricing for a model name (fuzzy match).
    private static func pricing(for model: String?) -> (input: Double, output: Double)? {
        guard let model = model?.lowercased(), !model.isEmpty else { return nil }
        // Exact match
        if let exact = pricingTable[model] { return exact }
        // Prefix match
        for (key, price) in pricingTable.sorted(by: { $0.key.count > $1.key.count }) {
            if model.contains(key) { return price }
        }
        return nil
    }

    /// Estimate cost for a single session based on its model, tool call count,
    /// and number of user/assistant turns observed.
    public static func estimateCost(
        model: String?,
        toolCallCount: Int,
        promptCount: Int = 1,
        replyCount: Int = 1
    ) -> Double {
        guard let price = pricing(for: model) else { return 0 }
        let inputTokens = Double(promptCount) * tokensPerPrompt
            + Double(toolCallCount) * tokensPerToolCall
        let outputTokens = Double(replyCount) * tokensPerReply
        let inputCost = (inputTokens / 1_000_000.0) * price.input
        let outputCost = (outputTokens / 1_000_000.0) * price.output
        return inputCost + outputCost
    }

    /// Incremental cost delta for one additional tool call.
    public static func incrementalToolCost(model: String?) -> Double {
        guard let price = pricing(for: model) else { return 0 }
        return (tokensPerToolCall / 1_000_000.0) * price.input
    }
}
