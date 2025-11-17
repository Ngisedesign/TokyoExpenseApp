import Foundation
import Vision
import UIKit

/// Represents a single text element with its spatial information
struct OCRTextElement {
    let text: String
    let boundingBox: CGRect  // Normalized coordinates (0-1, origin at bottom-left)
    let confidence: Float
}

struct OCRResult {
    let recognizedText: [String]  // Kept for backward compatibility
    let textElements: [OCRTextElement]  // NEW: Full spatial data
    let confidence: Float
    let boundingBoxes: [CGRect]  // Kept for backward compatibility
}

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Recognize text from an image using Vision Framework (async/await)
    /// - Parameters:
    ///   - image: The image to process
    ///   - language: Language code (default: "ja-JP" for Japanese)
    /// - Returns: OCRResult
    func recognizeText(
        in image: UIImage,
        language: String = "ja-JP"
    ) async -> OCRResult {
        await withCheckedContinuation { continuation in
            recognizeTextWithCompletion(in: image, language: language) { result in
                switch result {
                case .success(let ocrResult):
                    continuation.resume(returning: ocrResult)
                case .failure:
                    // Return empty result on error
                    let emptyResult = OCRResult(
                        recognizedText: [],
                        textElements: [],
                        confidence: 0,
                        boundingBoxes: []
                    )
                    continuation.resume(returning: emptyResult)
                }
            }
        }
    }

    /// Recognize text from an image using Vision Framework (completion handler)
    /// - Parameters:
    ///   - image: The image to process
    ///   - language: Language code (default: "ja-JP" for Japanese)
    ///   - completion: Callback with OCRResult or error
    private func recognizeTextWithCompletion(
        in image: UIImage,
        language: String = "ja-JP",
        completion: @escaping (Result<OCRResult, Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            var recognizedLines: [String] = []
            var boundingBoxes: [CGRect] = []
            var textElements: [OCRTextElement] = []
            var totalConfidence: Float = 0

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                recognizedLines.append(topCandidate.string)
                boundingBoxes.append(observation.boundingBox)

                // Create text element with spatial info
                let element = OCRTextElement(
                    text: topCandidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: topCandidate.confidence
                )
                textElements.append(element)

                totalConfidence += topCandidate.confidence
            }

            let averageConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)

            let result = OCRResult(
                recognizedText: recognizedLines,
                textElements: textElements,
                confidence: averageConfidence,
                boundingBoxes: boundingBoxes
            )

            completion(.success(result))
        }

        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [language]
        request.usesLanguageCorrection = true

        // Also support English for mixed receipts
        if language == "ja-JP" {
            request.recognitionLanguages = ["ja-JP", "en-US"]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Check if a language is supported for OCR
    /// - Parameter language: Language code (e.g., "ja-JP")
    /// - Returns: True if supported
    func isLanguageSupported(_ language: String) -> Bool {
        do {
            let request = VNRecognizeTextRequest()
            let supportedLanguages = try request.supportedRecognitionLanguages()
            return supportedLanguages.contains(language)
        } catch {
            return false
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case unsupportedLanguage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .unsupportedLanguage:
            return "Language not supported for OCR"
        }
    }
}
