import Testing

@testable import LetterGrid

struct NoiseScoreTests {
  private let rules = (0...3).map { WordRule(startDirections: Direction.allCases, turns: $0) }

  @Test func repeatedReadingsAreScoredOnceAndTheirSubtreesArePruned() {
    let board = Board(letters: Array(repeating: Array("AAAAAAA"), count: 7), placements: [])
    let words = Set((3...20).map { String(repeating: "A", count: $0) }).union(["UNRELATED"])
    #expect(board.strayWordCount(in: WordIndex(words), rules: rules, maximumVisits: 10_000) == 18)
  }

  @Test func anExhaustedSearchBudgetDoesNotClaimTheBoardIsClean() {
    let board = Board(letters: Array(repeating: Array("AAAAAAA"), count: 7), placements: [])
    let words: Set<String> = [String(repeating: "A", count: 40) + "B"]
    #expect(board.strayWordCount(in: WordIndex(words), rules: rules, maximumVisits: 10) == Int.max)
  }

  @Test func noisyDictionariesKeepNaturalFillerWithoutChangingTheOldGeneration() throws {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    let dictionary = Set(alphabet.flatMap { first in alphabet.map { "\(first)\($0)" } })
    let filler = try LetterWeights(
      Dictionary(uniqueKeysWithValues: alphabet.map { (String($0), 1.0) }))
    for version in [BoardGenerationVersion.v0p12, .v0p13] {
      let request = try BoardGenerator(
        columns: 7, rows: 7, rules: rules, filler: filler,
        layoutsPerAttempt: 4, attempts: 2, fillsPerAttempt: 2, generationVersion: version
      ).request(for: ["DIRECT", "SQUARE", "SAW"])
      let board = request.board(seed: 7, dictionary: dictionary)
      let occupied = Set(board.placements.flatMap(\.cells))
      let targetLetters = Set(request.words.joined())
      let ordinaryFiller = (0..<board.rows).contains { row in
        (0..<board.columns).contains { column in
          let cell = Cell(row: row, column: column)
          return !occupied.contains(cell) && targetLetters.contains(board[cell])
        }
      }
      #expect(ordinaryFiller == (version == .v0p13))
      for word in request.words { #expect(board.occurrences(of: word, rules: rules) == 1) }
    }
  }
}
