import Foundation
import CoreGraphics
import FoundationModels

/// Hybrid parser combining spatial analysis with Foundation Models semantic understanding
/// - Spatial Parser: Extracts amounts and dates (deterministic)
/// - Foundation Models: Extracts merchant names and categories (semantic)
@available(iOS 26.0, *)
class HybridParser {
    static let shared = HybridParser()

    private init() {}

    /// Parse receipt using hybrid approach
    /// - Parameters:
    ///   - textElements: OCR text elements with spatial information
    ///   - confidence: OCR confidence score
    /// - Returns: Parsed receipt data
    func parseReceipt(from textElements: [OCRTextElement], confidence: Float) async throws -> ParsedReceipt {
        print("🔄 Hybrid Parser - Combining spatial + semantic analysis")

        // Step 1: Use Spatial Parser for structured data (amounts, dates)
        let spatialResult = SpatialReceiptParser.shared.parseReceipt(
            from: textElements,
            confidence: confidence
        )

        // Step 2: Use Foundation Models for semantic understanding (merchant, category)
        let semanticData = try await extractSemanticInformation(from: textElements)

        // Step 3: Combine both results
        var finalReceipt = spatialResult
        finalReceipt.merchantName = semanticData.merchantName ?? spatialResult.merchantName
        finalReceipt.suggestedCategory = semanticData.category

        // Validate: If LLM and spatial disagree significantly on amount, prefer spatial
        if let llmAmount = semanticData.fallbackAmount,
           let spatialAmount = spatialResult.totalAmount {
            let difference = abs(Double(truncating: llmAmount as NSNumber) - Double(truncating: spatialAmount as NSNumber))
            let percentDiff = difference / Double(truncating: spatialAmount as NSNumber)

            if percentDiff > 0.2 {  // > 20% difference
                print("⚠️ LLM amount (\(llmAmount)) differs from spatial (\(spatialAmount)) by \(Int(percentDiff * 100))%")
                print("   Using spatial parsing result")
            }
        }

        print("✅ Hybrid Parser Final Result:")
        print("   Merchant: \(finalReceipt.merchantName ?? "nil")")
        print("   Amount: \(finalReceipt.totalAmount?.description ?? "nil") (from spatial)")
        print("   Category: \(finalReceipt.suggestedCategory ?? "nil") (from LLM)")

        return finalReceipt
    }

    // MARK: - Semantic Extraction

    /// Extract semantic information using Foundation Models
    private func extractSemanticInformation(from textElements: [OCRTextElement]) async throws -> ReceiptSemantics {
        // Convert text elements to simple line format for LLM
        let receiptText = textElements
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .map { $0.text }
            .joined(separator: "\n")

        let prompt = """
        Extract semantic information from this Japanese receipt.

        YOUR TASK:
        - Identify the merchant/store name
        - Classify the business type

        DO NOT extract amounts or dates - another system handles that.

        Receipt text:
        \(receiptText)
        """

        let session = LanguageModelSession()

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ReceiptSemantics.self
            )

            return response.content

        } catch {
            print("⚠️ Foundation Models error: \(error)")
            throw error
        }
    }
}

/// Semantic data extracted by Foundation Models
@Generable
struct ReceiptSemantics {
    @Guide(description: "The merchant or store name (e.g., ヨドバシカメラ, BOOKOFF, Lawson). Return nil if not found.")
    var merchantName: String?

    @Guide(description: "Business type: food, transport, shopping, electronics, or other")
    var category: String?

    @Guide(description: "Fallback total amount if spatial parsing fails. Only provide if clearly visible.")
    var fallbackAmount: Double?
}
