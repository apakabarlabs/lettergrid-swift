import Testing

@testable import LetterGrid

struct LoneReadingTests {
  private static let groups: [[Direction]] = [
    [.right, .down], [.downRight, .downLeft], [.left, .up], [.upLeft, .upRight],
  ]

  @Test(arguments: [0, 1, 2])
  func aLonePlacementReadsOnceExactlyWhenTheBoardSearchSaysSo(turns: Int) {
    let rules = (0...turns).flatMap { count in
      Self.groups.map { WordRule(startDirections: $0, turns: count) }
    }
    var random = SeededRandom(seed: UInt64(turns))
    var compared = 0
    for length in 4...9 {
      for rule in rules where rule.turns == turns {
        for direction in rule.startDirections {
          let shapes = PathShapes(
            columns: 7, length: length,
            rule: WordRule(startDirections: [direction], turns: turns),
            maximumShapes: Int.max, maximumRows: 7, visitedLimit: nil, randomized: false
          ).cells()
          for shape in shapes {
            let word = String((0..<length).map { _ in random.nextInt(below: 3) == 0 ? "B" : "A" })
            let placement = Placement(word: word, cells: shape)
            let expected = board(holding: placement).hasSingleOccurrence(of: word, rules: rules)
            #expect(
              placement.readsOnceAlone(rules: rules) == expected,
              "\(word) along \(shape) with \(turns) turns")
            compared += 1
          }
        }
      }
    }
    #expect(compared >= Direction.allCases.count * (4...7).count)
  }

  private func board(holding placement: Placement) -> Board {
    var letters = Array(repeating: Array(repeating: Character("."), count: 7), count: 7)
    for (cell, letter) in zip(placement.cells, placement.word) {
      letters[cell.row][cell.column] = letter
    }
    return Board(letters: letters, placements: [placement])
  }
}
