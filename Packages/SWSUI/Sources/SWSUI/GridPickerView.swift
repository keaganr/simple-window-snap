import SwiftUI
import SWSModel

/// Lets the user draw a new snap zone by dragging across a fixed grid of
/// cells (à la Rectangle's snap picker). Existing zones for the
/// configuration are drawn alongside so the user can see the whole layout
/// while adding a new one.
///
/// The grid lines are spaced to land on clean halves/thirds/quarters/fifths
/// (see `GridSelection`) rather than a uniform N-column grid, so dragging
/// between any two lines always produces a "nice" fraction.
public struct GridPickerView: View {
    private let columnBreakpoints: [Double]
    private let rowBreakpoints: [Double]
    private let existingZones: [NormalizedRect]
    private let onCommit: (NormalizedRect) -> Void
    private let onSelectExistingZone: (NormalizedRect) -> Void

    @State private var dragStartCell: (col: Int, row: Int)?
    @State private var dragCurrentCell: (col: Int, row: Int)?
    @State private var clickedExistingZone: NormalizedRect?

    public init(
        columnBreakpoints: [Double] = GridSelection.columnBreakpoints,
        rowBreakpoints: [Double] = GridSelection.rowBreakpoints,
        existingZones: [NormalizedRect],
        onCommit: @escaping (NormalizedRect) -> Void,
        onSelectExistingZone: @escaping (NormalizedRect) -> Void = { _ in }
    ) {
        self.columnBreakpoints = columnBreakpoints
        self.rowBreakpoints = rowBreakpoints
        self.existingZones = existingZones
        self.onCommit = onCommit
        self.onSelectExistingZone = onSelectExistingZone
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                gridLines()

                ForEach(existingZones, id: \.self) { zone in
                    zoneOverlay(zone, in: proxy.size, color: zone == clickedExistingZone ? .accentColor : .gray)
                }

                if let previewRect = currentPreviewRect {
                    zoneOverlay(previewRect, in: proxy.size, color: .accentColor)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startFractionX = value.startLocation.x / proxy.size.width
                        let startFractionY = value.startLocation.y / proxy.size.height
                        if let occupiedZone = ZoneHitTesting.zone(
                            containingFractionX: startFractionX, fractionY: startFractionY, in: existingZones
                        ) {
                            clickedExistingZone = occupiedZone
                            return
                        }
                        guard clickedExistingZone == nil else { return }

                        let start = GridSelection.cell(
                            atOffsetX: value.startLocation.x, offsetY: value.startLocation.y,
                            width: proxy.size.width, height: proxy.size.height,
                            columnBreakpoints: columnBreakpoints, rowBreakpoints: rowBreakpoints
                        )
                        let current = GridSelection.cell(
                            atOffsetX: value.location.x, offsetY: value.location.y,
                            width: proxy.size.width, height: proxy.size.height,
                            columnBreakpoints: columnBreakpoints, rowBreakpoints: rowBreakpoints
                        )
                        let candidateRect = GridSelection.normalizedRect(
                            fromStartCol: start.col, startRow: start.row,
                            currentCol: current.col, currentRow: current.row,
                            columnBreakpoints: columnBreakpoints, rowBreakpoints: rowBreakpoints
                        )
                        // Freeze the selection at its last valid extent rather than
                        // letting it grow into a cell an existing zone already occupies.
                        guard !existingZones.contains(where: { $0.intersects(candidateRect) }) else { return }

                        dragStartCell = start
                        dragCurrentCell = current
                    }
                    .onEnded { _ in
                        if let occupiedZone = clickedExistingZone {
                            onSelectExistingZone(occupiedZone)
                        } else if let rect = currentPreviewRect {
                            onCommit(rect)
                        }
                        dragStartCell = nil
                        dragCurrentCell = nil
                        clickedExistingZone = nil
                    }
            )
        }
        .aspectRatio(16.0 / 9, contentMode: .fit)
    }

    private var currentPreviewRect: NormalizedRect? {
        guard let start = dragStartCell, let current = dragCurrentCell else { return nil }
        return GridSelection.normalizedRect(
            fromStartCol: start.col, startRow: start.row,
            currentCol: current.col, currentRow: current.row,
            columnBreakpoints: columnBreakpoints, rowBreakpoints: rowBreakpoints
        )
    }

    private func gridLines() -> some View {
        Canvas { context, size in
            var path = Path()
            for fraction in columnBreakpoints {
                let x = CGFloat(fraction) * size.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for fraction in rowBreakpoints {
                let y = CGFloat(fraction) * size.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.gray.opacity(0.4)), lineWidth: 1)
        }
    }

    private func zoneOverlay(_ rect: NormalizedRect, in size: CGSize, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.3))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 2))
            .frame(width: rect.width * size.width, height: rect.height * size.height)
            .position(
                x: (rect.x + rect.width / 2) * size.width,
                y: (rect.y + rect.height / 2) * size.height
            )
    }
}
