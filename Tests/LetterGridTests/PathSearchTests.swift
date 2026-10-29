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
      let bareWords = bare.strayWords(in: dictionary, rules: rules)
      #expect(bare.strayWordCount(in: dictionary, rules: rules) == Set(bareWords).count)
      let row = String(grid[0])
      let covered = Board(
        letters: grid,
        placements: [Placement(word: row, start: Cell(row: 0, column: 0), direction: .right)])
      let coveredWords = covered.strayWords(in: dictionary, rules: rules)
      #expect(covered.strayWordCount(in: dictionary, rules: rules) == Set(coveredWords).count)
    }
  }

  @Test func aPreparedDictionaryBuildsTheSameBoardsAsTheWordSet() throws {
    let words: Set<String> = ["planet", "orbit", "lunar", "star", "moon", "solar", "sun"]
    let prepared = BoardDictionary(words)
    #expect(prepared.words.contains("PLANET"))
    let filler = try LetterWeights(["a": 1, "n": 1, "o": 1, "r": 1, "s": 1, "t": 1])
    let turned = try BoardGenerator(
      columns: 7, rows: 7, rules: rules, filler: filler
    ).request(for: ["PLANET", "ORBIT"], firstRule: rules[2])
    let straight = try BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down], filler: filler
    ).request(for: ["PLANET", "ORBIT"])
    for seed in UInt64(1)...12 {
      #expect(
        turned.board(seed: seed, dictionary: words)
          == turned.board(
            seed: seed, dictionary: prepared))
      #expect(
        straight.board(seed: seed, dictionary: words)
          == straight.board(
            seed: seed, dictionary: prepared))
    }
  }
}
