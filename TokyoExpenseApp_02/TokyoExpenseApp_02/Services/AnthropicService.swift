import Foundation
import UIKit
import ImageIO

/// Service for parsing receipts using Anthropic's Claude API
@available(iOS 18.0, *)
class AnthropicService {
    static let shared = AnthropicService()

    private let apiKey: String
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-haiku-20241022"

    private init() {
        self.apiKey = AppAPIKeys.anthropic
    }

    /// Parse a receipt image using Claude Vision
    func parseReceipt(image: UIImage) async throws -> ParsedReceipt {
        // Try to extract merchant from EXIF metadata first
        let metadataMerchant = extractMerchantFromMetadata(image: image)
        if let merchantFromMeta = metadataMerchant {
            print("📸 Found merchant in image metadata: \(merchantFromMeta)")
        }

        // Convert image to JPEG and base64
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw AnthropicError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()

        print("📤 Sending image to Claude API (size: \(imageData.count / 1024)KB)")

        // Build the API request
        let request = try buildRequest(base64Image: base64Image)

        // Make the API call with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        let session = URLSession(configuration: config)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // Handle network-specific errors
            if error.code == .timedOut {
                throw AnthropicError.networkTimeout
            } else if error.code == .notConnectedToInternet {
                throw AnthropicError.noInternetConnection
            } else {
                throw error
            }
        }

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        print("📥 Received response: HTTP \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: \(errorBody)")
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse the response
        return try parseResponse(data: data, metadataMerchant: metadataMerchant)
    }

    // MARK: - Private Methods

    private func buildRequest(base64Image: String) throws -> URLRequest {
        guard let url = URL(string: apiURL) else {
            throw AnthropicError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let prompt = """
You are a receipt parsing expert specializing in Japanese receipts. Extract ALL information you can find.

CRITICAL: If the receipt shows an explicit exchange rate converting JPY to USD (e.g., rates printed on a credit card slip) and/or a USD total, EXTRACT those and PREFER them over any external exchange rate APIs. Only omit if not visible.

IMPORTANT: Extract what you CAN see, even if some fields are missing!

What to look for:

1. Total Amount in JPY (HIGHEST PRIORITY):
   - Look for: 合計, 小計, 合計(税込), Total, Grand Total
   - Usually at the bottom of the receipt
   - Return the FINAL total (after tax if shown)

2. USD Total (if shown on the receipt):
   - Some card slips print both JPY and USD totals. If a USD total is printed, extract it.

3. Exchange Rate (if shown):
   - If a JPY→USD exchange rate is printed (e.g., 1 USD = 150 JPY or ¥150 = $1), extract it as JPY per 1 USD.

4. Merchant/Store Name:
   - Look for: Restaurant name, store name at TOP, or large logo text
   - Common stores: LAWSON, セブンイレブン, ファミリーマート, ドン・キホーテ, etc.
   - If NO clear merchant name is visible, you MUST invent a creative, whimsical Japanese-style placeholder name:
     * Use authentic Japanese naming patterns (kanji, hiragana, katakana, or English)
     * Keep it SHORT and SIMPLE (2-4 characters typical)
     * Be CREATIVE - avoid generic words like "レストラン", "食堂", "店"
     * Good examples by category:
       - Food: まる, さくら, はな, つき, やま, うみ, たけ
       - Food combos: 桜亭, 月の家, 花まる, 山小屋
       - Electronics: デジ丸, テック桜
       - With numbers: 38号まる, 梅田さくら
     * Make it sound like a REAL cozy Japanese place with personality
   - NEVER return null - always generate a creative Japanese name if real one isn't visible

5. Date:
   - Look for: Date near top of receipt
   - Common formats: 2024年11月18日, 2024/11/18, 2024-11-18
   - Return in format: YYYY-MM-DD
   - If not visible/cropped, set to null

6. Category (guess from context):
   - "Food/Per Diem": Food items, restaurants, convenience stores, cafes, supermarkets
   - "Transport": Taxis, trains, buses, subway, ride-shares
   - "Other": Everything else

7. Description (generate simple, natural description):
   - Infer from receipt items, merchant type, and timestamp
   - Simple categories: "Breakfast", "Lunch", "Dinner", "Snack", "Coffee", "Groceries", "Taxi", "Train", "Subway", "Convenience Store", etc.
   - Use time of day to help infer meal type if applicable
   - Keep it SHORT (1-2 words max)
   - Examples:
     * Morning convenience store → "Breakfast"
     * Afternoon restaurant → "Lunch"
     * Evening izakaya → "Dinner"
     * Coffee shop → "Coffee"
     * Taxi receipt → "Taxi"
     * Train station → "Train"
   - If unclear from context, use generic: "Purchase", "Meal", "Transport"

IMPORTANT:
- merchant: ALWAYS provide a name (real or whimsical placeholder)
- merchant_is_real: true if actual merchant name found, false if you invented a whimsical placeholder
- If date is missing, set to null (don't guess)
- ALWAYS extract the amount if visible
- Set confidence based on clarity (0.0-1.0)
- description: Provide a simple, concise description (1-2 words)

CRITICAL: Return ONLY the JSON object below. No markdown, no explanations, no commentary.

{
  "merchant": "Actual Store Name or Whimsical Placeholder",
  "merchant_is_real": true,
  "amount": 1234,
  "amount_usd": 12.34,
  "exchange_rate_jpy_per_usd": 150.0,
  "date": "2024-11-18 or null",
  "category": "Food/Per Diem",
  "description": "Lunch",
  "confidence": 0.85
}
"""

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        return request
    }

    private func parseResponse(data: Data, metadataMerchant: String?) throws -> ParsedReceipt {
        // Parse Anthropic API response
        let apiResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        // Extract the text content
        guard let textContent = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw AnthropicError.noTextInResponse
        }

        print("🤖 Claude response: \(textContent)")

        // Clean the response (Claude sometimes wraps JSON in markdown code blocks)
        let cleanedText = cleanJSONResponse(textContent)

        // Parse the JSON from Claude's response
        guard let jsonData = cleanedText.data(using: .utf8) else {
            print("❌ Failed to convert cleaned text to data")
            throw AnthropicError.invalidJSON
        }

        let receiptData: ReceiptJSON
        do {
            receiptData = try JSONDecoder().decode(ReceiptJSON.self, from: jsonData)
        } catch {
            print("❌ JSON decoding failed: \(error)")
            print("   Raw text: \(cleanedText)")
            throw AnthropicError.invalidJSON
        }

        print("📊 Parsed receipt data:")
        print("   Merchant: \(receiptData.merchant ?? "nil")")
        print("   Merchant is real: \(receiptData.merchantIsReal ?? false)")
        print("   Amount: \(receiptData.amount?.description ?? "nil")")
        print("   Amount USD: \(receiptData.amountUSD?.description ?? "nil")")
        print("   Exchange Rate (JPY/USD): \(receiptData.exchangeRateJPYPerUSD?.description ?? "nil")")
        print("   Date: \(receiptData.date ?? "nil")")
        print("   Category: \(receiptData.category ?? "nil")")
        print("   Description: \(receiptData.description ?? "nil")")
        print("   Confidence: \(receiptData.confidence?.description ?? "nil")")

        // Convert to ParsedReceipt
        var isPlaceholder = !(receiptData.merchantIsReal ?? true)
        var finalMerchantName = receiptData.merchant

        // Use metadata merchant as fallback if Claude generated a placeholder
        if isPlaceholder, let metaMerchant = metadataMerchant, !metaMerchant.isEmpty {
            finalMerchantName = metaMerchant
            isPlaceholder = false // Metadata is real
            print("✅ Using metadata merchant instead of AI placeholder")
        }

        return ParsedReceipt(
            merchantName: finalMerchantName,
            merchantIsPlaceholder: isPlaceholder,
            date: parseDate(receiptData.date),
            totalAmount: receiptData.amount.map { Decimal($0) },
            currency: "JPY",
            lineItems: [],
            confidence: receiptData.confidence ?? 0.8,
            isUberReceipt: finalMerchantName?.lowercased().contains("uber") ?? false,
            suggestedCategory: receiptData.category,
            expenseDescription: receiptData.description,
            exchangeRateJPYPerUSD: receiptData.exchangeRateJPYPerUSD.map { Decimal($0) },
            totalAmountUSD: receiptData.amountUSD.map { Decimal($0) }
        )
    }

    /// Extract merchant name from image EXIF metadata
    private func extractMerchantFromMetadata(image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        // Check common EXIF fields for merchant info
        // UserComment, ImageDescription, Copyright, etc.
        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let userComment = exif[kCGImagePropertyExifUserComment as String] as? String, !userComment.isEmpty {
                return userComment
            }
        }

        if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let imageDescription = tiff[kCGImagePropertyTIFFImageDescription as String] as? String, !imageDescription.isEmpty {
                return imageDescription
            }
            if let copyright = tiff[kCGImagePropertyTIFFCopyright as String] as? String, !copyright.isEmpty {
                return copyright
            }
        }

        // Check GPS UserComment
        if let gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let gpsComment = gps["UserComment"] as? String, !gpsComment.isEmpty {
                return gpsComment
            }
        }

        return nil
    }

    /// Remove markdown code blocks and extract only the JSON portion
    private func cleanJSONResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks (```json ... ``` or ``` ... ```)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract only the JSON part (from first { to last })
        // Claude sometimes adds commentary after the JSON
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}") {
            let range = firstBrace...lastBrace
            cleaned = String(cleaned[range])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = DateFormatter()

        // Try multiple date formats (including Japanese formats)
        let formats = [
            "yyyy-MM-dd",      // 2024-12-01
            "yyyy/MM/dd",      // 2024/12/01
            "yyyy年MM月dd日",   // 2024年12月01日 (Japanese format)
            "MM/dd/yyyy",      // 12/01/2024
            "dd/MM/yyyy",      // 01/12/2024
            "yyyyMMdd",        // 20241201
            "yy/MM/dd"         // 24/12/01
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                print("✅ Parsed date '\(dateString)' using format '\(format)'")
                return date
            }
        }

        print("⚠️ Could not parse date: '\(dateString)'")
        return nil
    }
}

// MARK: - Supporting Types

enum AnthropicError: LocalizedError {
    case imageConversionFailed
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noTextInResponse
    case invalidJSON
    case networkTimeout
    case noInternetConnection

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Unable to process receipt image. Please try taking another photo."
        case .invalidURL:
            return "Configuration error. Please contact support."
        case .invalidResponse:
            return "Received unexpected response from server. Please try again."
        case .apiError(let statusCode, _):
            return userFriendlyAPIError(statusCode: statusCode)
        case .noTextInResponse:
            return "Unable to read receipt. Please ensure the image is clear and well-lit."
        case .invalidJSON:
            return "Unable to process receipt data. Please try again or enter details manually."
        case .networkTimeout:
            return "Request timed out. Please check your internet connection and try again."
        case .noInternetConnection:
            return "No internet connection. Please connect to Wi-Fi or cellular data and try again."
        }
    }

    private func userFriendlyAPIError(statusCode: Int) -> String {
        switch statusCode {
        case 401:
            return "API key is invalid or expired. Please check your configuration."
        case 429:
            return "Too many requests. Please wait a moment and try again."
        case 500...599:
            return "Server error. Please try again in a few moments."
        case 400:
            return "Invalid request. The receipt image may be corrupted. Please try another photo."
        default:
            return "Unable to process receipt (Error \(statusCode)). Please try again or enter details manually."
        }
    }
}

struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

struct ReceiptJSON: Codable {
    let merchant: String?
    let merchantIsReal: Bool?
    let amount: Double?
    let amountUSD: Double?
    let exchangeRateJPYPerUSD: Double?
    let date: String?
    let category: String?
    let confidence: Float?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case merchant
        case merchantIsReal = "merchant_is_real"
        case amount
        case amountUSD = "amount_usd"
        case exchangeRateJPYPerUSD = "exchange_rate_jpy_per_usd"
        case date
        case category
        case confidence
        case description
    }
}
