import Foundation
import CoreGraphics

/// Spatial-based receipt parser using Vision Framework bounding box coordinates
/// Finds amounts by looking for numbers near keywords like "合計"
@available(iOS 18.0, *)
class SpatialReceiptParser {
    static let shared = SpatialReceiptParser()

    private init() {}

    /// Parse receipt using spatial analysis of text elements
    func parseReceipt(from textElements: [OCRTextElement], confidence: Float) -> ParsedReceipt {
        print("📍 Spatial Parser - Processing \(textElements.count) text elements")

        // Sort elements by vertical position (top to bottom)
        let sortedElements = textElements.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        // Extract structured data using spatial relationships
        let merchantName = extractMerchantName(from: sortedElements)
        let date = extractDate(from: sortedElements)
        let totalAmount = extractTotalAmount(from: sortedElements)
        let isUber = merchantName?.lowercased().contains("uber") ?? false

        var receipt = ParsedReceipt(
            lineItems: [],
            confidence: confidence,
            isUberReceipt: isUber
        )

        receipt.merchantName = merchantName
        receipt.date = date
        receipt.totalAmount = totalAmount
        receipt.currency = "JPY"
        receipt.suggestedCategory = nil  // Will be filled by semantic parser

        print("✅ Spatial Parser Extracted:")
        print("   Merchant: \(receipt.merchantName ?? "nil")")
        print("   Date: \(receipt.date?.description ?? "nil")")
        print("   Amount: \(receipt.totalAmount?.description ?? "nil")")

        return receipt
    }

    // MARK: - Extraction Methods

    /// Extract merchant name (typically at the top of receipt)
    private func extractMerchantName(from elements: [OCRTextElement]) -> String? {
        // Look at top 5 elements
        let topElements = Array(elements.prefix(5))

        // Skip noise (receipt/領収書, dates, numbers)
        let noiseKeywords = ["領収", "レシート", "receipt", "様"]

        for element in topElements {
            let text = element.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip if too short or contains noise
            guard text.count > 1 else { continue }
            let containsNoise = noiseKeywords.contains { text.contains($0) }
            let containsOnlyNumbers = text.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil

            if !containsNoise && !containsOnlyNumbers {
                return text
            }
        }

        return elements.first?.text
    }

    /// Extract total amount by finding numbers near "合計" keyword
    private func extractTotalAmount(from elements: [OCRTextElement]) -> Decimal? {
        print("📊 Searching for total amount using spatial analysis...")

        // Strategy 1: Find "合計" keyword and look for nearby numbers
        for (index, element) in elements.enumerated() {
            if element.text.contains("合計") || element.text.contains("小計") {
                print("   Found total keyword '\(element.text)' at position \(element.boundingBox)")

                // Check if amount is on the same line
                if let amount = extractAmount(from: element.text) {
                    print("   ✅ Found amount on same line: ¥\(amount)")
                    return amount
                }

                // Look for numbers near this keyword (spatially close)
                if let nearbyAmount = findNumberNear(element: element.boundingBox, in: elements, searchRadius: 0.15) {
                    print("   ✅ Found amount near keyword: ¥\(nearbyAmount)")
                    return nearbyAmount
                }

                // Check next few lines (split amount case)
                for nextIndex in (index + 1)...min(index + 3, elements.count - 1) {
                    let nextElement = elements[nextIndex]
                    if let amount = extractAmount(from: nextElement.text) {
                        print("   ✅ Found amount on following line: ¥\(amount)")
                        return amount
                    }
                }
            }
        }

        // Strategy 2: Find standalone large amounts (likely the total)
        let candidates = elements.compactMap { element -> (Decimal, CGRect)? in
            guard let amount = extractAmount(from: element.text),
                  amount > 100 && amount < 10_000_000 else { return nil }
            return (amount, element.boundingBox)
        }

        if let largest = candidates.max(by: { $0.0 < $1.0 }) {
            print("   💰 Using largest reasonable amount: ¥\(largest.0)")
            return largest.0
        }

        print("   ⚠️ Could not find total amount")
        return nil
    }

    /// Extract date by finding Japanese date patterns
    private func extractDate(from elements: [OCRTextElement]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")

        for element in elements {
            let text = element.text

            // Try Japanese format: 2019年01月06日
            if let match = text.range(of: #"[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日"#, options: .regularExpression) {
                let dateString = String(text[match])
                dateFormatter.dateFormat = "yyyy年MM月dd日"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                dateFormatter.dateFormat = "yyyy年M月d日"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }

            // Try slash format: 2019/01/06
            if let match = text.range(of: #"[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}"#, options: .regularExpression) {
                let dateString = String(text[match])
                dateFormatter.dateFormat = "yyyy/MM/dd"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                dateFormatter.dateFormat = "yyyy/M/d"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    /// Find a number spatially near a given element
    private func findNumberNear(element: CGRect, in elements: [OCRTextElement], searchRadius: CGFloat) -> Decimal? {
        for candidate in elements {
            // Calculate distance between bounding boxes
            let distance = distanceBetween(element, candidate.boundingBox)

            if distance < searchRadius {
                if let amount = extractAmount(from: candidate.text) {
                    print("      Distance: \(distance), Text: '\(candidate.text)' → ¥\(amount)")
                    return amount
                }
            }
        }
        return nil
    }

    /// Calculate distance between two bounding boxes (normalized coordinates)
    private func distanceBetween(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let center1 = CGPoint(x: rect1.midX, y: rect1.midY)
        let center2 = CGPoint(x: rect2.midX, y: rect2.midY)

        let dx = center1.x - center2.x
        let dy = center1.y - center2.y

        return sqrt(dx * dx + dy * dy)
    }

    /// Extract decimal amount from text (handles ¥, 円, commas)
    private func extractAmount(from text: String) -> Decimal? {
        // Normalize text
        let normalized = text.replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Try to extract number patterns
        let patterns = [
            #"([0-9]{1,3}(,[0-9]{3})+)"#,  // With commas: 159,810
            #"([0-9]{3,})"#                  // Without commas: 159810
        ]

        for pattern in patterns {
            if let match = normalized.range(of: pattern, options: .regularExpression) {
                let amountString = String(normalized[match])
                    .replacingOccurrences(of: ",", with: "")

                if let amount = Decimal(string: amountString), amount >= 10 {
                    return amount
                }
            }
        }

        return nil
    }
}
