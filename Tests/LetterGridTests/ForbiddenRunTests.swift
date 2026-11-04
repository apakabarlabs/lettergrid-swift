import Testing

@testable import LetterGrid

struct ForbiddenRunTests {
  @Test(.timeLimit(.minutes(1)))
  func wordsWhoseFirstShapesLineUpALetterStillGetABoard() throws {
    let groups: [[Direction]] = [
      [.right, .down], [.downRight, .downLeft], [.left, .up], [.upLeft, .upRight],
    ]
    let rules =
      [0, 1].flatMap { turns in groups.map { WordRule(startDirections: $0, turns: turns) } }
      + groups.prefix(3).map { WordRule(startDirections: $0, turns: 2) }
    let words = ["ᲞᲐᲢᲐᲠᲐ", "ᲙᲔᲓᲔᲚᲘ", "ᲛᲝᲛᲪᲠᲝ"]
    let generator = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7, maxRows: 7),
      rules: rules,
      filler: Filler(
        weights: try LetterWeights(
          Dictionary(words.joined().map { (String($0), 1.0) }, uniquingKeysWith: +))),
      limits: PlacementLimits(maxWordsPerDirection: 2)
    )
    let request = try generator.request(for: words, leadingRules: [])
    #expect(Set(request.words) == Set(words))
  }
}
