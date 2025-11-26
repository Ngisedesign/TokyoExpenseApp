//
//  AppTheme.swift
//  TokyoExpenseApp
//
//  Centralized theme system with dark mode support
//

import SwiftUI

// MARK: - App Color Palette

struct AppTheme {

    // MARK: - Category Colors

    /// Category colors that adapt to light/dark mode
    struct CategoryColors {

        /// Food (Per Diem) - Blue tones
        static var food: Color {
            Color(light: Color(hue: 0.58, saturation: 0.45, brightness: 0.85),
                  dark: Color(hue: 0.58, saturation: 0.50, brightness: 0.70))
        }

        /// Transport - Green tones
        static var transport: Color {
            Color(light: Color(hue: 0.33, saturation: 0.40, brightness: 0.70),
                  dark: Color(hue: 0.33, saturation: 0.45, brightness: 0.60))
        }

        /// Flight - Cyan tones
        static var flight: Color {
            Color(light: Color(hue: 0.53, saturation: 0.45, brightness: 0.80),
                  dark: Color(hue: 0.53, saturation: 0.50, brightness: 0.65))
        }

        /// Hotel - Purple tones
        static var hotel: Color {
            Color(light: Color(hue: 0.75, saturation: 0.40, brightness: 0.75),
                  dark: Color(hue: 0.75, saturation: 0.45, brightness: 0.65))
        }

        /// Other - Gray tones
        static var other: Color {
            Color(light: Color(hue: 0.0, saturation: 0.0, brightness: 0.60),
                  dark: Color(hue: 0.0, saturation: 0.0, brightness: 0.55))
        }
    }

    // MARK: - Semantic Colors

    /// Semantic colors for UI states
    struct SemanticColors {

        /// Warning/overspending color - Red
        static var overspending: Color {
            Color(light: Color(hue: 0.0, saturation: 0.75, brightness: 0.55),
                  dark: Color(hue: 0.0, saturation: 0.70, brightness: 0.70))
        }

        /// Success/positive color - Green
        static var success: Color {
            Color(light: Color(hue: 0.33, saturation: 0.60, brightness: 0.55),
                  dark: Color(hue: 0.33, saturation: 0.55, brightness: 0.65))
        }

        /// Pill/button background (unselected state)
        static var pillBackground: Color {
            Color(light: Color.black.opacity(0.05),
                  dark: Color.white.opacity(0.10))
        }

        /// Pill/button foreground (unselected state)
        static var pillForeground: Color {
            Color(light: Color.black,
                  dark: Color.white)
        }
    }

    // MARK: - Background Colors

    /// Background colors for different contexts
    struct Backgrounds {

        /// Card background
        static var card: Color {
            Color(light: Color(uiColor: .systemBackground),
                  dark: Color(uiColor: .systemBackground))
        }

        /// Grouped background (for lists)
        static var grouped: Color {
            Color(light: Color(uiColor: .systemGroupedBackground),
                  dark: Color(uiColor: .systemGroupedBackground))
        }

        /// Secondary grouped background
        static var secondaryGrouped: Color {
            Color(light: Color(uiColor: .secondarySystemGroupedBackground),
                  dark: Color(uiColor: .secondarySystemGroupedBackground))
        }

        /// Light gray background
        static var lightGray: Color {
            Color(light: Color(uiColor: .systemGray6),
                  dark: Color(uiColor: .systemGray5))
        }
    }

    // MARK: - Gradient Colors

    /// Colors for gradients and overlays
    struct Gradients {

        /// Currency toggle gradient - white layers
        static var currencyWhiteLayers: [Double] {
            [0.22, 0.10, 0.06, 0.35, 0.55, 0.05, 0.0, 0.25]
        }

        /// Currency toggle gradient - black overlay
        static var currencyBlackOpacity: Double {
            0.45
        }

        /// Adaptive white for gradients
        static func white(opacity: Double) -> Color {
            Color(light: Color.white.opacity(opacity),
                  dark: Color.white.opacity(opacity * 0.3))
        }

        /// Adaptive black for gradients
        static func black(opacity: Double) -> Color {
            Color(light: Color.black.opacity(opacity),
                  dark: Color.black.opacity(opacity * 0.6))
        }
    }

    // MARK: - PDF Export Colors

    /// Light background colors for PDF export (these stay light even in dark mode)
    struct PDFExport {

        static var foodBackground: UIColor {
            UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        }

        static var transportBackground: UIColor {
            UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
        }

        static var flightBackground: UIColor {
            UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        }

        static var hotelBackground: UIColor {
            UIColor(red: 0.95, green: 0.9, blue: 1.0, alpha: 1.0)
        }

        static var otherBackground: UIColor {
            UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        }
    }
}

// MARK: - Color Extension for Light/Dark Mode

extension Color {

    /// Creates an adaptive color that changes based on light/dark mode
    /// - Parameters:
    ///   - light: Color to use in light mode
    ///   - dark: Color to use in dark mode
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor(light: UIColor(light), dark: UIColor(dark)))
    }
}

// MARK: - UIColor Extension for Light/Dark Mode

extension UIColor {

    /// Creates an adaptive UIColor that changes based on light/dark mode
    /// - Parameters:
    ///   - light: UIColor to use in light mode
    ///   - dark: UIColor to use in dark mode
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            case .light, .unspecified:
                return light
            @unknown default:
                return light
            }
        }
    }
}
