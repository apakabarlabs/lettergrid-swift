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
}
