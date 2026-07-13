import SWSModel

/// Maps a dragged cell span on a fixed, non-uniform grid to a
/// `NormalizedRect`. Pure and SwiftUI-agnostic so it's testable independent
/// of `GridPickerView`.
///
/// The grid isn't evenly spaced: its line positions are the union of the
/// fractions needed to draw clean halves/thirds/quarters/fifths, so dragging
/// from one line to another always lands on a "nice" fraction instead of an
/// arbitrary decimal.
public enum GridSelection {
    /// Column boundaries (0...1) covering halves, thirds, quarters, and
    /// fifths.
    public static let columnBreakpoints: [Double] = [
        0, 1.0 / 5, 1.0 / 4, 1.0 / 3, 2.0 / 5, 1.0 / 2, 3.0 / 5, 2.0 / 3, 3.0 / 4, 4.0 / 5, 1,
    ]

    /// Row boundaries (0...1) covering halves and thirds.
    public static let rowBreakpoints: [Double] = [0, 1.0 / 3, 1.0 / 2, 2.0 / 3, 1]

    public static func normalizedRect(
        fromStartCol startCol: Int,
        startRow: Int,
        currentCol: Int,
        currentRow: Int,
        columnBreakpoints: [Double] = columnBreakpoints,
        rowBreakpoints: [Double] = rowBreakpoints
    ) -> NormalizedRect {
        let minCol = min(startCol, currentCol)
        let maxCol = max(startCol, currentCol)
        let minRow = min(startRow, currentRow)
        let maxRow = max(startRow, currentRow)
        let x = columnBreakpoints[minCol]
        let y = rowBreakpoints[minRow]
        return NormalizedRect(
            x: x,
            y: y,
            width: columnBreakpoints[maxCol + 1] - x,
            height: rowBreakpoints[maxRow + 1] - y
        )
    }

    /// Maps a pixel offset within a picker of the given size to the index of
    /// the grid segment (0..<breakpoints.count - 1) it falls within.
    public static func cell(
        atOffsetX offsetX: Double, offsetY: Double,
        width: Double, height: Double,
        columnBreakpoints: [Double] = columnBreakpoints,
        rowBreakpoints: [Double] = rowBreakpoints
    ) -> (col: Int, row: Int) {
        let fractionX = min(1, max(0, offsetX / width))
        let fractionY = min(1, max(0, offsetY / height))
        return (
            segmentIndex(forFraction: fractionX, in: columnBreakpoints),
            segmentIndex(forFraction: fractionY, in: rowBreakpoints)
        )
    }

    private static func segmentIndex(forFraction fraction: Double, in breakpoints: [Double]) -> Int {
        let lastSegment = breakpoints.count - 2
        for segment in 0...lastSegment {
            if fraction < breakpoints[segment + 1] {
                return segment
            }
        }
        return lastSegment
    }
}
