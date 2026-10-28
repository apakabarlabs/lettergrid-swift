import Testing

@testable import LetterGrid

struct UnboundedSeedGoldenTests {
  @Test func packedGenerationRetainsTheReleasedBoard() throws {
    let rules = (0...1).map { WordRule(startDirections: [.right, .down], turns: $0) }
    let board = try BoardGenerator(
      columns: 5, rows: 5, maxRows: 5, rules: rules, filler: filler(), downWords: 1...2,
      generationVersion: .v0p18
    ).request(for: ["PLANET", "ORBIT", "SUN"], firstRule: rules[1]).board(seed: 37)
    let letters = "SUXQZ/PNQQQ/LZZZO/ANETR/XZTIB"
    let placements =
      "PLANET=1,0;2,0;3,0;3,1;3,2;3,3"
      + "|ORBIT=2,4;3,4;4,4;4,3;4,2|SUN=0,0;0,1;1,1"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test(arguments: [BoardGenerationVersion.v0p17, .v0p18])
  func conditionalCopiesRetainTheReleasedBoard(version: BoardGenerationVersion) throws {
    let board = try BoardGenerator(
      columns: 5, rows: 5, maxRows: 5, directions: [.right, .down], filler: filler(),
      downWords: 1...2, generationVersion: version, conditionalCharacters: ["É"]
    ).request(for: ["AÉ", "C-D"]).board(seed: 37)
    let letters = "QZQZX/ZZZQZ/XCQAQ/Q-ÉÉ-/XDQQQ"
    let placements = "AÉ=2,3;3,3|C-D=2,1;3,1;4,1"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test(arguments: [BoardGenerationVersion.v0p9, .v0p12, .v0p13, .v0p17, .v0p18])
  func straightGenerationRetainsTheReleasedBoard(version: BoardGenerationVersion) throws {
    let board = try BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down], filler: filler(),
      downWords: 1...2, layoutsPerAttempt: 4, attempts: 2, fillsPerAttempt: 2,
      generationVersion: version
    ).request(for: ["CAT", "DOG", "SUN"]).board(seed: 37)
    let letters = "ZCZQZ/QAZXQ/STDOG/UQZXQ/NZQQX"
    let placements = "CAT=0,1;1,1;2,1|DOG=2,2;2,3;2,4|SUN=2,0;3,0;4,0"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test(arguments: [BoardGenerationVersion.v0p9, .v0p12, .v0p13, .v0p17, .v0p18])
  func straightFallbackRetainsTheReleasedBoard(version: BoardGenerationVersion) throws {
    let board = try BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down], filler: filler(),
      downWords: 1...2, attempts: 0, generationVersion: version
    ).request(for: ["CAT", "DOG", "SUN"]).board(seed: 37)
    let letters =
      version == .v0p9
      ? "CZSXZ/AXUXZ/TQNZZ/XZZZZ/DOGXX" : "CZSZZ/AXUZQ/TZNZQ/XZXXX/DOGQZ"
    let placements = "CAT=0,0;1,0;2,0|DOG=4,0;4,1;4,2|SUN=0,2;1,2;2,2"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test(arguments: [BoardGenerationVersion.v0p12, .v0p13, .v0p17, .v0p18])
  func turnedGenerationRetainsTheReleasedBoard(version: BoardGenerationVersion) throws {
    let rules = (0...2).map { WordRule(startDirections: [.right, .down], turns: $0) }
    let board = try BoardGenerator(
      columns: 5, rows: 5, rules: rules, filler: filler(), downWords: 1...2,
      layoutsPerAttempt: 4, attempts: 2, fillsPerAttempt: 2, generationVersion: version
    ).request(for: ["PLANET", "ORBIT", "SUN"], firstRule: rules[2]).board(seed: 37)
    let letters = "ZPORZ/ALNBQ/NSUIX/EZXTX/TXQZZ"
    let placements =
      "PLANET=0,1;1,1;1,0;2,0;3,0;4,0"
      + "|ORBIT=0,2;0,3;1,3;2,3;3,3|SUN=2,1;2,2;1,2"
    #expect(signature(board) == letters + "|" + placements)
  }

  private func filler() throws -> LetterWeights {
    try LetterWeights(["x": 1, "q": 2, "z": 3])
  }

  private func signature(_ board: Board) -> String {
    let letters = board.letters.map { String($0) }.joined(separator: "/")
    let placements = board.placements.map { placement in
      placement.word + "=" + placement.cells.map { "\($0.row),\($0.column)" }.joined(separator: ";")
    }.joined(separator: "|")
    return letters + "|" + placements
  }
}
