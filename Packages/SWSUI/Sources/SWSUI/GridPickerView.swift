import SwiftUI
import SWSModel

/// Lets the user draw a new snap zone by dragging across a fixed grid of
/// cells (à la Rectangle's snap picker). Existing zones for the
/// configuration are drawn alongside so the user can see the whole layout
/// while adding a new one.
public struct GridPickerView: View {
    private let columns: Int
    private let rows: Int
    private let existingZones: [NormalizedRect]
    private let onCommit: (NormalizedRect) -> Void
    private let onSelectExistingZone: (NormalizedRect) -> Void

    @State private var dragStartCell: (col: Int, row: Int)?
    @State private var dragCurrentCell: (col: Int, row: Int)?
    @State private var clickedExistingZone: NormalizedRect?

    public init(
        columns: Int = 16, rows: Int = 9, existingZones: [NormalizedRect],
        onCommit: @escaping (NormalizedRect) -> Void,
        onSelectExistingZone: @escaping (NormalizedRect) -> Void = { _ in }
    ) {
        self.columns = columns
        self.rows = rows
        self.existingZones = existingZones
        self.onCommit = onCommit
        self.onSelectExistingZone = onSelectExistingZone
    }

    public var body: some View {
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / CGFloat(columns)
            let cellHeight = proxy.size.height / CGFloat(rows)

            ZStack {
                gridLines(cellWidth: cellWidth, cellHeight: cellHeight)

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
                            cellWidth: cellWidth, cellHeight: cellHeight, columns: columns, rows: rows
                        )
                        let current = GridSelection.cell(
                            atOffsetX: value.location.x, offsetY: value.location.y,
                            cellWidth: cellWidth, cellHeight: cellHeight, columns: columns, rows: rows
                        )
                        let candidateRect = GridSelection.normalizedRect(
                            fromStartCol: start.col, startRow: start.row,
                            currentCol: current.col, currentRow: current.row,
                            columns: columns, rows: rows
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
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
    }

    private var currentPreviewRect: NormalizedRect? {
        guard let start = dragStartCell, let current = dragCurrentCell else { return nil }
        return GridSelection.normalizedRect(
            fromStartCol: start.col, startRow: start.row,
            currentCol: current.col, currentRow: current.row,
            columns: columns, rows: rows
        )
    }

    private func gridLines(cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        Canvas { context, size in
            var path = Path()
            for col in 0...columns {
                let x = CGFloat(col) * cellWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 0...rows {
                let y = CGFloat(row) * cellHeight
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
