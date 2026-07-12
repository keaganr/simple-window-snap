import SWSModel

/// Maps a dragged cell span on a fixed grid to a `NormalizedRect`. Pure and
/// SwiftUI-agnostic so it's testable independent of `GridPickerView`.
public enum GridSelection {
    public static func normalizedRect(
        fromStartCol startCol: Int,
        startRow: Int,
        currentCol: Int,
        currentRow: Int,
        columns: Int,
        rows: Int
    ) -> NormalizedRect {
        let minCol = min(startCol, currentCol)
        let maxCol = max(startCol, currentCol)
        let minRow = min(startRow, currentRow)
        let maxRow = max(startRow, currentRow)
        return NormalizedRect(
            x: Double(minCol) / Double(columns),
            y: Double(minRow) / Double(rows),
            width: Double(maxCol - minCol + 1) / Double(columns),
            height: Double(maxRow - minRow + 1) / Double(rows)
        )
    }

    /// Clamps a pixel offset within a picker of the given cell size to a
    /// valid column/row index (0..<columns / 0..<rows).
    public static func cell(atOffsetX offsetX: Double, offsetY: Double, cellWidth: Double, cellHeight: Double, columns: Int, rows: Int) -> (col: Int, row: Int) {
        let col = min(columns - 1, max(0, Int(offsetX / cellWidth)))
        let row = min(rows - 1, max(0, Int(offsetY / cellHeight)))
        return (col, row)
    }
}
