struct PlacementCoverage {
  private struct DirectedStart: Hashable {
    let cell: Cell
    let direction: Direction
  }

  private let lengths: [DirectedStart: Int]

  init(_ placements: [Placement]) {
    let readings = placements + placements.filter(\.isPalindrome).map(\.reversed)
    var lengths: [DirectedStart: Int] = [:]
    for placement in readings {
      let cells = placement.cells
      for (offset, cell) in cells.enumerated() {
        let start = DirectedStart(cell: cell, direction: placement.direction)
        lengths[start] = max(lengths[start] ?? 0, cells.count - offset)
      }
    }
    self.lengths = lengths
  }

  func length(from start: Cell, along direction: Direction) -> Int {
    lengths[DirectedStart(cell: start, direction: direction)] ?? 0
  }
}
