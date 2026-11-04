struct PlacedRuns {
  let columns: Int
  let rows: Int

  func formed(
    by placement: Placement, letters: [Character?], among chosen: [Placement?]
  ) -> Bool {
    let length = Generation.settings.fill.runLength
    return placement.cells.contains { cell in
      Direction.lineAxes.contains { axis in
        (0..<length).contains { offset in
          let run = (0..<length).map { cell.moved(axis, by: $0 - offset) }
          guard run.allSatisfy(isOnBoard), let letter = letters[slot(of: run[0])],
            run.allSatisfy({ letters[slot(of: $0)] == letter })
          else { return false }
          return !chosen.contains { placed in
            placed.map { $0.containsReading(run) || $0.containsReading(Array(run.reversed())) }
              ?? false
          }
        }
      }
    }
  }

  private func isOnBoard(_ cell: Cell) -> Bool {
    (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
  }

  private func slot(of cell: Cell) -> Int { cell.row * columns + cell.column }
}
