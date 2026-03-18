import Foundation

/// Parsed habit data returned from Claude API
struct ParsedHabitData: Codable {
    let name: String
    let description: String?
    let tier: String
    let type: String
    let frequencyType: String
    let frequencyTarget: Int
    let successCriteria: String?
    let options: [String]?
    let habitPrompt: String
    let scheduleTimes: [String]?
    let isHobby: Bool
}

/// Errors from the Claude API service
enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case httpError(Int)
    case unauthorized
    case rateLimited
    case serverError
    case decodingError
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Set up your API key in Settings"
        case .networkError:
            return "No internet connection"
        case .httpError(let code):
            return "Server error (\(code))"
        case .unauthorized:
            return "Invalid API key"
        case .rateLimited:
            return "Too many requests — try again in a moment"
        case .serverError:
            return "Server error — try again"
        case .decodingError:
            return "Try rephrasing your habit"
        case .timeout:
            return "Request timed out"
        }
    }

    var canRetry: Bool {
        switch self {
        case .networkError, .rateLimited, .serverError, .timeout, .httpError:
            return true
        case .noAPIKey, .unauthorized, .decodingError:
            return false
        }
    }

    var shouldShowSettings: Bool {
        switch self {
        case .noAPIKey, .unauthorized:
            return true
        default:
            return false
        }
    }
}

/// Service for calling the Anthropic Claude API to parse natural language habit descriptions
@Observable
class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-20250514"
    private let timeoutInterval: TimeInterval = 15

    private init() {}

    private let systemPrompt = """
    You are a habit-parsing assistant for a habit tracking app called Sown. The user will describe a habit they want to build or break in plain English. Extract structured data from their description and return ONLY valid JSON (no markdown, no explanation).

    Return this exact JSON structure:
    {
      "name": "Short habit name (2-4 words, capitalize first letter)",
      "description": null,
      "tier": "must_do" or "nice_to_do",
      "type": "positive" or "negative",
      "frequencyType": "daily" or "weekly" or "monthly" or "once",
      "frequencyTarget": 1,
      "successCriteria": null or "measurable target string",
      "options": null or ["option1", "option2"],
      "habitPrompt": "A tiny first-step motivation (e.g. 'Put on your trainers and step outside')",
      "scheduleTimes": null or ["After Wake", "Morning", "During the Day", "Evening", "Before Bed"],
      "isHobby": false
    }

    Rules:
    - "tier": Use "must_do" for essential daily habits (exercise, sleep, hygiene, health, productivity). Use "nice_to_do" for hobbies, leisure, nice-to-have goals.
    - "type": Use "positive" for habits to build (do more of). Use "negative" for habits to stop/quit/reduce (e.g. "stop smoking", "quit junk food", "less screen time").
    - "frequencyType": Default to "daily". Use "weekly" if they mention "X times a week" or specific days. Use "monthly" if they mention monthly. Use "once" for one-time tasks.
    - "frequencyTarget": For daily, use 1. For weekly, use the number of times per week (default 3). For monthly, use the number of times per month.
    - "successCriteria": Only set if the user mentions a specific measurable target (e.g. "10 minutes", "5km", "8 glasses"). Format as a clear string like "10 minutes" or "5 km".
    - "options": Only set if the user mentions multiple ways to complete the habit (e.g. "run or swim or bike"). Otherwise null.
    - "habitPrompt": ALWAYS generate this. It should be a tiny, actionable first step that makes starting easy. Focus on the physical action to begin, not the end goal.
    - "scheduleTimes": Set based on context. Morning routines → ["After Wake"] or ["Morning"]. Evening habits → ["Evening"] or ["Before Bed"]. Exercise → ["Morning"] or ["During the Day"]. If unclear, null.
    - "isHobby": Set true only for creative/leisure activities like reading, drawing, music, photography, cooking for fun.
    """

    func parseHabit(input: String) async throws -> ParsedHabitData {
        guard let apiKey = APIKeyStorage.load(), !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "temperature": 0.3,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": input]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeAPIError.timeout
        } catch {
            throw ClaudeAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ClaudeAPIError.unauthorized
        case 429:
            throw ClaudeAPIError.rateLimited
        case 500...599:
            throw ClaudeAPIError.serverError
        default:
            throw ClaudeAPIError.httpError(httpResponse.statusCode)
        }

        // Parse the Anthropic response format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeAPIError.decodingError
        }

        // Claude might wrap JSON in markdown code blocks — strip them
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw ClaudeAPIError.decodingError
        }

        do {
            let parsed = try JSONDecoder().decode(ParsedHabitData.self, from: jsonData)
            return parsed
        } catch {
            throw ClaudeAPIError.decodingError
        }
    }
}
