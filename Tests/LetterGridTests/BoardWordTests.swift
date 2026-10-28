import Testing

@testable import LetterGrid

struct BoardWordTests {
  @Test func resultsKeepStartDirectionAndPrefixOrderIncludingDuplicates() {
    let board = Board(letters: [Array("ABABA")], placements: [])
    let dictionary: Set<String> = ["A", "AB", "ABA", "BA", "", "ABABAX"]
    let directions: [Direction] = [.right, .left, .right]

    checkReadings(on: board, dictionary: dictionary, directions: directions)
  }

  @Test(arguments: Direction.allCases)
  func onlyReadingsInsideAParallelPlacementAreExcluded(_ direction: Direction) throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [direction, direction.opposite],
      filler: try LetterWeights(["x": 1, "y": 1, "z": 1, "q": 1]))
    let dictionary: Set<String> = ["L", "LE", "EVE", "LEVEL", "CAT", "TAC", "AT", "SUN", "NU"]
    for seed: UInt64 in 1...10 {
      let board = try generator.board(for: ["LEVEL", "CAT", "SUN"], seed: seed)
      checkReadings(on: board, dictionary: dictionary, directions: Direction.allCases)
    }
  }

  @Test func unicodeReadingsKeepCanonicalEquivalenceAndCellBoundaries() {
    let rows: [[Character]] = [
      ["a", "\u{301}", "x"],
      ["\u{1100}", "\u{1161}", "x"],
      ["🇦", "🇲", "x"],
      ["é", "և", "ß"],
    ]
    let dictionary: Set<String> = ["á", "áx", "가", "가x", "🇦🇲", "e\u{301}և", "ևß"]
    let board = Board(letters: rows, placements: [])
    checkReadings(on: board, dictionary: dictionary, directions: Direction.allCases)
  }

  @Test func canonicalMatchesReturnTheBoardsSpellingAndDoNotFoldCase() {
    let board = Board(letters: [Array("éևßCAT")], placements: [])
    checkReadings(
      on: board, dictionary: ["e\u{301}և", "cat", "CAT", "ßC"], directions: [.right, .left])
    #expect(board.strayWords(of: ["cat"], along: [.right]).isEmpty)
  }

  private func checkReadings(
    on board: Board, dictionary: Set<String>, directions: [Direction]
  ) {
    let readings = [
      board.strayWords(of: dictionary, along: directions),
      BoardWordSearch(board: board, dictionary: .words(dictionary)).words(along: directions),
      BoardWordSearch(board: board, dictionary: .indexed(WordIndex(dictionary)))
        .words(along: directions),
    ]
    let expected = scannedWords(on: board, dictionary: dictionary, directions: directions)
    for actual in readings {
      #expect(actual.map { Array($0.unicodeScalars) } == expected.map { Array($0.unicodeScalars) })
    }
  }

  @Test func emptyBoardsDictionariesAndDirectionsHaveNoReadings() {
    let board = Board(letters: [Array("CAT")], placements: [])
    #expect(board.strayWords(of: [], along: [.right]).isEmpty)
    #expect(board.strayWords(of: ["CAT"], along: []).isEmpty)
    #expect(Board(letters: [], placements: []).strayWords(of: ["CAT"], along: [.right]).isEmpty)
  }

  @Test func aSmallBoardWithALargeDictionaryKeepsTheSameReadings() {
    let board = Board(letters: [Array("CAT"), Array("DOG"), Array("SUN")], placements: [])
    let dictionary = Set((0..<5000).map { "UNRELATED\($0)" }).union(["CAT", "DOG", "SUN", "cat"])
    checkReadings(on: board, dictionary: dictionary, directions: Direction.allCases)
  }

  private func scannedWords(
    on board: Board, dictionary: Set<String>, directions: [Direction]
  ) -> [String] {
    var words: [String] = []
    for row in 0..<board.rows {
      for column in 0..<board.columns {
        for direction in directions {
          var cells: [Cell] = []
          var cell = Cell(row: row, column: column)
          while board.contains(cell) {
            cells.append(cell)
            let text = board.text(along: cells)
            let intended = board.placements.contains {
              ($0.direction == direction || ($0.isPalindrome && $0.direction.opposite == direction))
                && Set($0.cells).isSuperset(of: cells)
            }
            if dictionary.contains(text), !intended { words.append(text) }
            cell = cell.moved(direction, by: 1)
          }
        }
      }
    }
    return words
  }
}
