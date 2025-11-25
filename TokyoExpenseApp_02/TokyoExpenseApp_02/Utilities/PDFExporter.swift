import UIKit
import PDFKit

class PDFExporter {
    static let shared = PDFExporter()
    
    private init() {}
    
    // Page settings (A4)
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 40.0
    private let contentWidth: CGFloat = 515.2 // 595.2 - 80
    
    // Column widths (proportional to contentWidth)
    // No (5%), Date (12%), Category (10%), Merchant (18%), Description (20%), JPY (10%), Rate (8%), USD (10%), Rec (7%)
    private let colWidths: [CGFloat] = [25, 60, 50, 90, 100, 50, 40, 50, 35]
    
    func createPDF(expenses: [Expense], filenameMap: [UUID: [String]]) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let metaData = [
            kCGPDFContextTitle: "Expense Report",
            kCGPDFContextAuthor: "TokyoExpenseApp"
        ]
        format.documentInfo = metaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        let data = renderer.pdfData { (context) in
            var currentY = margin
            
            // Start first page
            context.beginPage()
            drawHeader(context: context.cgContext, y: &currentY)
            
            // Draw Table Header
            drawTableHeader(context: context.cgContext, y: &currentY)
            
            // Draw Rows
            for (index, expense) in expenses.enumerated() {
                // Check if we need a new page
                if currentY > pageHeight - margin - 20 {
                    context.beginPage()
                    currentY = margin
                    drawTableHeader(context: context.cgContext, y: &currentY)
                }
                
                drawRow(context: context.cgContext, expense: expense, index: index, filenameMap: filenameMap, y: &currentY)
            }
            
            // Draw Total
            if currentY > pageHeight - margin - 40 {
                context.beginPage()
                currentY = margin
            }
            drawTotal(context: context.cgContext, expenses: expenses, y: &currentY)
            
            // Draw Footer
            if currentY > pageHeight - margin - 100 {
                context.beginPage()
                currentY = margin
            }
            drawFooter(context: context.cgContext, y: &currentY)
            
            // Append Receipts
            for (index, expense) in expenses.enumerated() {
                if let firstPath = expense.receiptImagePaths.first,
                   let image = ImageManager.shared.loadImage(firstPath) {
                    
                    context.beginPage()
                    currentY = margin
                    
                    // Draw Header
                    let headerText = "Receipt #\(String(format: "%03d", index + 1)) - \(expense.merchantName)"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 18),
                        .foregroundColor: UIColor.black
                    ]
                    headerText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: attributes)
                    currentY += 40
                    
                    // Draw Image (Scale to fit)
                    let maxWidth = pageWidth - (margin * 2)
                    let maxHeight = pageHeight - currentY - margin
                    
                    let aspectWidth = maxWidth / image.size.width
                    let aspectHeight = maxHeight / image.size.height
                    let aspectRatio = min(aspectWidth, aspectHeight)
                    
                    let scaledWidth = image.size.width * aspectRatio
                    let scaledHeight = image.size.height * aspectRatio
                    
                    let x = margin + (maxWidth - scaledWidth) / 2
                    
                    image.draw(in: CGRect(x: x, y: currentY, width: scaledWidth, height: scaledHeight))
                }
            }
        }
        
        return data
    }
    
    private func drawHeader(context: CGContext, y: inout CGFloat) {
        let title = "Expense Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 20
        
        // Add Top Fields: Date, Employee Name, Signed
        let fieldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let fields = [
            "Date: _______________________",
            "Employee Name: _______________________",
            "Signed: _______________________"
        ]
        
        let fieldHeight: CGFloat = 20
        
        for field in fields {
            field.draw(at: CGPoint(x: margin, y: y), withAttributes: fieldAttributes)
            y += fieldHeight
        }
        
        y += 20 // Spacing before table
    }

    private func drawFooter(context: CGContext, y: inout CGFloat) {
        y += 40 // Spacing before footer
        
        let fieldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let fields = [
            "PRPL Manager: _______________________",
            "Google Project #: _______________________",
            "Signed: _______________________"
        ]
        
        let fieldHeight: CGFloat = 25
        
        for field in fields {
            field.draw(at: CGPoint(x: margin, y: y), withAttributes: fieldAttributes)
            y += fieldHeight
        }
    }
    
    private func drawTableHeader(context: CGContext, y: inout CGFloat) {
        let headers = ["No.", "Date", "Category", "Merchant", "Description", "JPY", "Rate", "USD", "Rec."]
        let xOffsets = getXOffsets()
        
        let _: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        
        // Draw background
        context.setFillColor(UIColor.systemGray6.cgColor)
        context.fill(CGRect(x: margin, y: y, width: contentWidth, height: 20))
        
        for (i, header) in headers.enumerated() {
            let rect = CGRect(x: margin + xOffsets[i], y: y + 4, width: colWidths[i], height: 16)
            let style = NSMutableParagraphStyle()
            style.alignment = (i >= 5 && i <= 7) ? .right : (i == 8 ? .center : .left)
            
            let cellAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: style
            ]
            
            header.draw(in: rect, withAttributes: cellAttr)
        }
        
        y += 20
    }
    
    private func drawRow(context: CGContext, expense: Expense, index: Int, filenameMap: [UUID: [String]], y: inout CGFloat) {
        let xOffsets = getXOffsets()
        let rowHeight: CGFloat = 24
        
        // Alternating row color
        if index % 2 != 0 {
            context.setFillColor(UIColor.systemGray6.withAlphaComponent(0.3).cgColor)
            context.fill(CGRect(x: margin, y: y, width: contentWidth, height: rowHeight))
        }
        
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .paragraphStyle: style
        ]
        
        // 1. No.
        drawText("\(index + 1)", x: margin + xOffsets[0], y: y, w: colWidths[0], attr: attributes)
        
        // 2. Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: expense.date)
        drawText(dateStr, x: margin + xOffsets[1], y: y, w: colWidths[1], attr: attributes)
        
        // 3. Category
        drawText(expense.category, x: margin + xOffsets[2], y: y, w: colWidths[2], attr: attributes)
        
        // 4. Merchant
        drawText(expense.merchantName, x: margin + xOffsets[3], y: y, w: colWidths[3], attr: attributes)
        
        // 5. Description
        drawText(expense.expenseDescription, x: margin + xOffsets[4], y: y, w: colWidths[4], attr: attributes)
        
        // 6. JPY (Right align)
        let jpyStyle = NSMutableParagraphStyle()
        jpyStyle.alignment = .right
        let jpyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .paragraphStyle: jpyStyle]
        drawText(CurrencyFormatter.format(yen: expense.amountJPY, showYen: true), x: margin + xOffsets[5], y: y, w: colWidths[5], attr: jpyAttr)
        
        // 7. Rate (Right align)
        let rateStr = String(format: "%.2f", NSDecimalNumber(decimal: expense.exchangeRate).doubleValue)
        drawText(rateStr, x: margin + xOffsets[6], y: y, w: colWidths[6], attr: jpyAttr)
        
        // 8. USD (Right align, bold)
        let usdStyle = NSMutableParagraphStyle()
        usdStyle.alignment = .right
        let usdAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .paragraphStyle: usdStyle]
        drawText(CurrencyFormatter.format(usd: expense.amountUSD, showYen: false), x: margin + xOffsets[7], y: y, w: colWidths[7], attr: usdAttr)
        
        // 9. Receipt (Center)
        let recStyle = NSMutableParagraphStyle()
        recStyle.alignment = .center
        let recAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .paragraphStyle: recStyle]
        
        // Determine receipt text (e.g., "#001")
        // We assume the caller has already renamed images to match this index
        let recText = expense.receiptImagePaths.isEmpty ? "-" : String(format: "#%03d", index + 1)
        drawText(recText, x: margin + xOffsets[8], y: y, w: colWidths[8], attr: recAttr)
        
        // Bottom border
        context.setStrokeColor(UIColor.systemGray5.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y + rowHeight))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y + rowHeight))
        context.strokePath()
        
        y += rowHeight
    }
    
    private func drawTotal(context: CGContext, expenses: [Expense], y: inout CGFloat) {
        y += 10
        let totalUSD = expenses.reduce(Decimal(0)) { $0 + $1.amountUSD }
        
        let text = "Grand Total: \(CurrencyFormatter.format(usd: totalUSD, showYen: false))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let x = margin + contentWidth - textSize.width
        
        text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }
    
    private func drawText(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, attr: [NSAttributedString.Key: Any]) {
        let rect = CGRect(x: x, y: y + 6, width: w, height: 14)
        text.draw(in: rect, withAttributes: attr)
    }
    
    private func getXOffsets() -> [CGFloat] {
        var offsets: [CGFloat] = [0]
        var current: CGFloat = 0
        for width in colWidths.dropLast() {
            current += width
            offsets.append(current)
        }
        return offsets
    }
}
