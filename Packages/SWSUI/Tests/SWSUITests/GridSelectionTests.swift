import Testing
@testable import SWSUI
import SWSModel

@Test func normalizedRectForSingleCellSelection() {
    let rect = GridSelection.normalizedRect(fromStartCol: 1, startRow: 1, currentCol: 1, currentRow: 1, columns: 6, rows: 4)
    #expect(rect == NormalizedRect(x: 1.0 / 6, y: 1.0 / 4, width: 1.0 / 6, height: 1.0 / 4))
}

@Test func normalizedRectForMultiCellSelection() {
    // Select columns 0-1, rows 0-3 (left third of a 6-wide, 4-tall grid).
    let rect = GridSelection.normalizedRect(fromStartCol: 0, startRow: 0, currentCol: 1, currentRow: 3, columns: 6, rows: 4)
    #expect(rect == NormalizedRect(x: 0, y: 0, width: 2.0 / 6, height: 1))
}

@Test func normalizedRectHandlesDragInEitherDirection() {
    // Dragging from bottom-right back to top-left should produce the same rect.
    let forward = GridSelection.normalizedRect(fromStartCol: 0, startRow: 0, currentCol: 2, currentRow: 2, columns: 6, rows: 4)
    let backward = GridSelection.normalizedRect(fromStartCol: 2, startRow: 2, currentCol: 0, currentRow: 0, columns: 6, rows: 4)
    #expect(forward == backward)
}

@Test func cellClampsOffsetsWithinGridBounds() {
    let cell = GridSelection.cell(atOffsetX: -50, offsetY: 10_000, cellWidth: 100, cellHeight: 100, columns: 6, rows: 4)
    #expect(cell.col == 0)
    #expect(cell.row == 3)
}

@Test func cellComputesCorrectIndexWithinBounds() {
    let cell = GridSelection.cell(atOffsetX: 250, offsetY: 150, cellWidth: 100, cellHeight: 100, columns: 6, rows: 4)
    #expect(cell.col == 2)
    #expect(cell.row == 1)
}
