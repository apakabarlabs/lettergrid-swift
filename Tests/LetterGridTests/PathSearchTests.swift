import Testing

@testable import LetterGrid

struct PathSearchTests {
  private let rules = (0...3).map { WordRule(startDirections: Direction.allCases, turns: $0) }

  @Test func countingStrayWordsAgreesWithTheFullSearch() {
    let dictionary = WordIndex(["AB", "ABC", "BAD", "CAB", "DAD", "ABBA", "CDDC"])
    var random = SeededRandom(seed: 11)
    let letters: [Character] = ["A", "B", "C", "D"]
    for _ in 0..<200 {
      let grid = (0..<4).map { _ in
        (0..<4).map { _ in letters[Int(random.next() % UInt64(letters.count))] }
      }
      let bare = Board(letters: grid, placements: [])
      #expect(
        bare.strayWordCount(in: dictionary, rules: rules) == strayWords(on: bare, in: dictionary))
      let row = String(grid[0])
      let covered = Board(
        letters: grid,
        placements: [Placement(word: row, start: Cell(row: 0, column: 0), direction: .right)])
      #expect(
        covered.strayWordCount(in: dictionary, rules: rules)
          == strayWords(on: covered, in: dictionary))
    }
  }

  private func strayWords(on board: Board, in dictionary: WordIndex) -> Int {
    Set(
      PathSearch(board: board, rules: rules).readings(in: dictionary)
        .filter { !board.covers($0) }.map(\.word)
    ).count
  }
}
