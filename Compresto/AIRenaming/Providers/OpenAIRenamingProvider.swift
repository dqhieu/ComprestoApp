//
//  OpenAIRenamingProvider.swift
//  Compresto
//

import Foundation

struct OpenAIRenamingProvider: AIRenamingProvider {
  let providerType = AIRenamingProviderType.openai

  private let baseURL = "https://api.openai.com/v1/chat/completions"
  private let timeoutInterval: TimeInterval = 15

  private let apiKey: String
  private let model: String

  init(apiKey: String, model: OpenAIModel = .gpt5Nano) {
    self.apiKey = apiKey
    self.model = model.rawValue
  }

  func generateName(
    imageData: Data,
    mimeType: String,
    preset: AIRenamingPreset,
    customPrompt: String?
  ) async -> AIRenamingResult {
    let base64Image = imageData.base64EncodedString()
    let systemPrompt = preset == .custom ? (customPrompt ?? preset.systemPrompt) : preset.systemPrompt

    let requestBody: [String: Any] = [
      "model": model,
      "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": [
          ["type": "text", "text": "Name this image."],
          ["type": "image_url", "image_url": [
            "url": "data:\(mimeType);base64,\(base64Image)",
            "detail": "low"
          ]]
        ]]
      ]
    ]

    guard let url = URL(string: baseURL) else {
      return .failure(error: "Invalid API URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = timeoutInterval

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      return .failure(error: "Failed to encode request")
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        switch httpResponse.statusCode {
        case 200:
          break
        case 401:
          return .failure(error: "Invalid API key")
        case 429:
          return .failure(error: "Rate limit exceeded")
        default:
          let errorMessage = parseErrorMessage(from: data)
          return .failure(error: "API error (HTTP \(httpResponse.statusCode)): \(errorMessage)")
        }
      }

      #if DEBUG
      print("[AIRenaming] Raw JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
      #endif

      let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
      guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
        let refusal = decoded.choices.first?.message.refusal
        return .failure(error: refusal ?? "Empty response from API")
      }

      #if DEBUG
      print("[AIRenaming] Raw AI response: \"\(content)\"")
      #endif
      let sanitized = AIRenamingFilenameSanitizer.sanitize(content)
      #if DEBUG
      print("[AIRenaming] Sanitized: \"\(sanitized)\"")
      #endif
      let tokens = decoded.usage?.totalTokens ?? 0
      return .success(suggested: content, sanitized: sanitized, tokens: tokens)

    } catch is URLError {
      return .failure(error: "Network error — check your connection")
    } catch {
      return .failure(error: "Failed to parse API response")
    }
  }

  private func parseErrorMessage(from data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = json["error"] as? [String: Any],
       let message = error["message"] as? String {
      return message
    }
    return "Unknown error"
  }

  func validateAPIKey(_ key: String) async -> Bool {
    guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
    var request = URLRequest(url: url)
    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 10

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        return httpResponse.statusCode == 200
      }
      return false
    } catch {
      return false
    }
  }
}

// MARK: - OpenAI Response Models

private struct OpenAIChatResponse: Decodable {
  let choices: [Choice]
  let usage: Usage?

  struct Choice: Decodable {
    let message: Message
  }

  struct Message: Decodable {
    let content: String?
    let refusal: String?
  }

  struct Usage: Decodable {
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
      case totalTokens = "total_tokens"
    }
  }
}
