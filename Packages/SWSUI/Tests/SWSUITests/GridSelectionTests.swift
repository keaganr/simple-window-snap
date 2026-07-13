import Testing
@testable import SWSUI
import SWSModel

private let testColumns: [Double] = [0, 0.25, 0.5, 0.75, 1]
private let testRows: [Double] = [0, 1.0 / 3, 2.0 / 3, 1]

@Test func normalizedRectForSingleCellSelection() {
    let rect = GridSelection.normalizedRect(
        fromStartCol: 1, startRow: 1, currentCol: 1, currentRow: 1,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    #expect(rect == NormalizedRect(x: 0.25, y: 1.0 / 3, width: 0.25, height: 1.0 / 3))
}

@Test func normalizedRectForMultiCellSelection() {
    // Select columns 0-1 (left half), rows 0-2 (full height) of a
    // quarters-wide, thirds-tall test grid.
    let rect = GridSelection.normalizedRect(
        fromStartCol: 0, startRow: 0, currentCol: 1, currentRow: 2,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    #expect(rect == NormalizedRect(x: 0, y: 0, width: 0.5, height: 1))
}

@Test func normalizedRectHandlesDragInEitherDirection() {
    // Dragging from bottom-right back to top-left should produce the same rect.
    let forward = GridSelection.normalizedRect(
        fromStartCol: 0, startRow: 0, currentCol: 2, currentRow: 1,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    let backward = GridSelection.normalizedRect(
        fromStartCol: 2, startRow: 1, currentCol: 0, currentRow: 0,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    #expect(forward == backward)
}

@Test func cellClampsOffsetsWithinGridBounds() {
    let cell = GridSelection.cell(
        atOffsetX: -50, offsetY: 10_000, width: 400, height: 300,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    #expect(cell.col == 0)
    #expect(cell.row == 2)
}

@Test func cellComputesCorrectIndexWithinBounds() {
    // x=250/400=0.625 falls in the [0.5, 0.75) segment -> column index 2.
    // y=150/300=0.5 falls in the [1/3, 2/3) segment -> row index 1.
    let cell = GridSelection.cell(
        atOffsetX: 250, offsetY: 150, width: 400, height: 300,
        columnBreakpoints: testColumns, rowBreakpoints: testRows
    )
    #expect(cell.col == 2)
    #expect(cell.row == 1)
}

@Test func defaultColumnBreakpointsProduceCleanFractions() {
    let breakpoints = GridSelection.columnBreakpoints
    #expect(breakpoints.first == 0)
    #expect(breakpoints.last == 1)
    #expect(breakpoints.contains(1.0 / 2))
    #expect(breakpoints.contains(1.0 / 3))
    #expect(breakpoints.contains(2.0 / 3))
    #expect(breakpoints.contains(1.0 / 4))
    #expect(breakpoints.contains(3.0 / 4))
    #expect(breakpoints.contains(1.0 / 5))
    #expect(breakpoints.contains(2.0 / 5))
    #expect(breakpoints.contains(3.0 / 5))
    #expect(breakpoints.contains(4.0 / 5))
}

@Test func defaultRowBreakpointsProduceCleanFractions() {
    let breakpoints = GridSelection.rowBreakpoints
    #expect(breakpoints.first == 0)
    #expect(breakpoints.last == 1)
    #expect(breakpoints.contains(1.0 / 2))
    #expect(breakpoints.contains(1.0 / 3))
    #expect(breakpoints.contains(2.0 / 3))
}
