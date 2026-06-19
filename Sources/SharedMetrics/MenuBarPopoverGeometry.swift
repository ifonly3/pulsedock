import CoreGraphics

public enum MenuBarPopoverGeometry {
    private static let windowChromeAllowance: CGFloat = 28

    public enum AnchorKind: Equatable {
        case statusBar
        case regular
    }

    public enum Edge: Equatable {
        case minY
        case maxY
    }

    public struct Placement: Equatable {
        public let size: CGSize
        public let preferredEdge: Edge
        public let availableHeight: CGFloat
        public let anchorScreenMidX: CGFloat?
    }

    public static func placement(
        preferredSize: CGSize,
        minimumHeight: CGFloat,
        screenMargin: CGFloat,
        visibleFrame: CGRect?,
        anchorFrame: CGRect?,
        anchorKind: AnchorKind
    ) -> Placement {
        let availableHeight = visibleFrame == nil
            ? preferredSize.height
            : availableHeight(
                screenMargin: screenMargin,
                visibleFrame: visibleFrame,
                anchorFrame: anchorFrame,
                anchorKind: anchorKind
            )
        let height = clampedHeight(
            preferredHeight: preferredSize.height,
            minimumHeight: minimumHeight,
            availableHeight: availableHeight
        )
        let width = clampedWidth(
            preferredWidth: preferredSize.width,
            screenMargin: screenMargin,
            visibleFrame: visibleFrame
        )

        return Placement(
            size: CGSize(width: width, height: height),
            preferredEdge: preferredEdge(
                screenMargin: screenMargin,
                visibleFrame: visibleFrame,
                anchorFrame: anchorFrame,
                anchorKind: anchorKind,
                contentHeight: height
            ),
            availableHeight: availableHeight,
            anchorScreenMidX: anchorScreenMidX(
                contentWidth: width,
                screenMargin: screenMargin,
                visibleFrame: visibleFrame,
                anchorFrame: anchorFrame
            )
        )
    }

    public static func constrainedWindowFrame(
        _ proposedFrame: CGRect,
        visibleFrame: CGRect,
        screenMargin: CGFloat
    ) -> CGRect {
        let horizontalMargin = min(max(0, screenMargin), max(0, visibleFrame.width / 2))
        let verticalMargin = min(max(0, screenMargin), max(0, visibleFrame.height / 2))
        let availableFrame = visibleFrame.insetBy(dx: horizontalMargin, dy: verticalMargin)
        let constrainedWidth = min(proposedFrame.width, availableFrame.width)
        let constrainedHeight = min(proposedFrame.height, availableFrame.height)
        let constrainedX = min(max(proposedFrame.minX, availableFrame.minX), availableFrame.maxX - constrainedWidth)
        let constrainedY = min(max(proposedFrame.minY, availableFrame.minY), availableFrame.maxY - constrainedHeight)

        return CGRect(
            x: constrainedX,
            y: constrainedY,
            width: constrainedWidth,
            height: constrainedHeight
        )
    }

    private static func anchorScreenMidX(
        contentWidth: CGFloat,
        screenMargin: CGFloat,
        visibleFrame: CGRect?,
        anchorFrame: CGRect?
    ) -> CGFloat? {
        guard let visibleFrame, let anchorFrame else { return nil }

        let halfWidth = contentWidth / 2
        let minimumCenter = visibleFrame.minX + halfWidth + screenMargin
        let maximumCenter = visibleFrame.maxX - halfWidth - screenMargin

        guard minimumCenter <= maximumCenter else {
            return visibleFrame.midX
        }

        return min(max(anchorFrame.midX, minimumCenter), maximumCenter)
    }

    private static func clampedWidth(
        preferredWidth: CGFloat,
        screenMargin: CGFloat,
        visibleFrame: CGRect?
    ) -> CGFloat {
        guard let visibleFrame else { return preferredWidth }
        let horizontalMargin = min(max(0, screenMargin), max(0, visibleFrame.width / 2))
        return min(preferredWidth, max(0, visibleFrame.width - horizontalMargin * 2))
    }

    private static func availableHeight(
        screenMargin: CGFloat,
        visibleFrame: CGRect?,
        anchorFrame: CGRect?,
        anchorKind: AnchorKind
    ) -> CGFloat {
        guard let visibleFrame else { return 1 }

        let rawAvailableHeight: CGFloat
        if anchorKind == .statusBar {
            if let anchorFrame {
                rawAvailableHeight = anchorFrame.minY - visibleFrame.minY - screenMargin
            } else {
                rawAvailableHeight = visibleFrame.height - screenMargin * 2
            }
        } else if let anchorFrame {
            let availableBelow = max(0, anchorFrame.minY - visibleFrame.minY - screenMargin)
            let availableAbove = max(0, visibleFrame.maxY - anchorFrame.maxY - screenMargin)
            rawAvailableHeight = max(availableBelow, availableAbove)
        } else {
            rawAvailableHeight = visibleFrame.height - screenMargin * 2
        }

        let availableHeightAfterChrome = rawAvailableHeight - windowChromeAllowance
        return max(1, availableHeightAfterChrome)
    }

    private static func preferredEdge(
        screenMargin: CGFloat,
        visibleFrame: CGRect?,
        anchorFrame: CGRect?,
        anchorKind: AnchorKind,
        contentHeight: CGFloat
    ) -> Edge {
        guard anchorKind != .statusBar else { return .minY }
        guard let visibleFrame, let anchorFrame else { return .minY }

        let availableBelow = max(0, anchorFrame.minY - visibleFrame.minY - screenMargin)
        let availableAbove = max(0, visibleFrame.maxY - anchorFrame.maxY - screenMargin)
        if availableBelow >= contentHeight || availableBelow >= availableAbove {
            return .minY
        }
        return .maxY
    }

    private static func clampedHeight(
        preferredHeight: CGFloat,
        minimumHeight: CGFloat,
        availableHeight: CGFloat
    ) -> CGFloat {
        let visibleHeight = min(preferredHeight, max(1, availableHeight))
        guard availableHeight >= minimumHeight else { return visibleHeight }
        return max(minimumHeight, visibleHeight)
    }
}
