import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: ProposedViewSize.unspecified)
        }
    }

    private func flow(proposal: ProposedViewSize, subviews: Subviews, spacing: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // New line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            points.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxWidth == .infinity ? maxX : maxWidth, height: currentY + lineHeight), points)
    }
}
