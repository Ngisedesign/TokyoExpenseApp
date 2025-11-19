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

        let (data, response) = try await session.data(for: request)

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
        return try parseResponse(data: data)
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

**CRITICAL: Extract what you CAN see, even if some fields are missing!**

**What to look for:**

1. **Total Amount** (HIGHEST PRIORITY):
   - Look for: 合計, 小計, 合計(税込), Total, Grand Total
   - Usually at the bottom of the receipt
   - Return the FINAL total (after tax if shown)

2. **Merchant/Store Name**:
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

3. **Date**:
   - Look for: Date near top of receipt
   - Common formats: 2024年11月18日, 2024/11/18, 2024-11-18
   - Return in format: YYYY-MM-DD
   - If not visible/cropped, set to null

4. **Category** (guess from context):
   - "Food/Per Diem": Food items, restaurants, convenience stores, cafes, supermarkets
   - "Transport": Taxis, trains, buses, subway, ride-shares
   - "Other": Everything else

**IMPORTANT:**
- merchant: ALWAYS provide a name (real or whimsical placeholder)
- merchant_is_real: true if actual merchant name found, false if you invented a whimsical placeholder
- If date is missing, set to null (don't guess)
- ALWAYS extract the amount if visible
- Set confidence based on clarity (0.0-1.0)

**CRITICAL: Return ONLY the JSON object below. No markdown, no explanations, no commentary.**

{
  "merchant": "Actual Store Name or Whimsical Placeholder",
  "merchant_is_real": true,
  "amount": 1234,
  "date": "2024-11-18 or null",
  "category": "Food/Per Diem",
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

    private func parseResponse(data: Data) throws -> ParsedReceipt {
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
        print("   Date: \(receiptData.date ?? "nil")")
        print("   Category: \(receiptData.category ?? "nil")")
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
            suggestedCategory: receiptData.category
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

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .noTextInResponse:
            return "No text content in API response"
        case .invalidJSON:
            return "Could not parse JSON from response"
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
    let date: String?
    let category: String?
    let confidence: Float?

    enum CodingKeys: String, CodingKey {
        case merchant
        case merchantIsReal = "merchant_is_real"
        case amount
        case date
        case category
        case confidence
    }
}
