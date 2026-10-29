import Testing

@testable import LetterGrid

struct UnboundedSeedGoldenTests {
  @Test func packedGenerationKeepsItsRecordedBoard() throws {
    let rules = (0...1).map { WordRule(startDirections: [.right, .down], turns: $0) }
    let board = try BoardGenerator(
      columns: 5, rows: 5, maxRows: 5, rules: rules, filler: filler(), downWords: 1...2
    ).request(for: ["PLANET", "ORBIT", "SUN"], firstRule: rules[1]).board(seed: 37)
    let letters = "QLORO/PSTBN/LURIP/ANETB/USIAE"
    let placements =
      "PLANET=1,0;2,0;3,0;3,1;3,2;3,3"
      + "|ORBIT=0,2;0,3;1,3;2,3;3,3|SUN=1,1;2,1;3,1"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test func conditionalCopiesKeepTheirRecordedBoard() throws {
    let board = try BoardGenerator(
      columns: 5, rows: 5, maxRows: 5, directions: [.right, .down], filler: filler(),
      downWords: 1...2, conditionalCharacters: ["É"]
    ).request(for: ["AÉ", "C-D"]).board(seed: 37)
    let letters = "QZQXZ/XD-CQ/ZAQAZ/QÉZXÉ/ZXC-D"
    let placements = "AÉ=2,1;3,1|C-D=4,2;4,3;4,4"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test func growingStraightGenerationKeepsItsRecordedBoard() throws {
    let board = try BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down], filler: filler(), downWords: 1...2
    ).request(for: ["CAT", "DOG", "SUN"]).board(seed: 37)
    let letters = "ZCSUN/UTNCZ/SXDAG/DOGTQ/ZAQOZ"
    let placements = "CAT=1,3;2,3;3,3|DOG=3,0;3,1;3,2|SUN=0,2;0,3;0,4"
    #expect(signature(board) == letters + "|" + placements)
  }

  @Test func growingTurnedGenerationKeepsItsRecordedBoard() throws {
    let rules = (0...2).map { WordRule(startDirections: [.right, .down], turns: $0) }
    let board = try BoardGenerator(
      columns: 5, rows: 5, rules: rules, filler: filler(), downWords: 1...2
    ).request(for: ["PLANET", "ORBIT", "SUN"], firstRule: rules[2]).board(seed: 37)
    let letters = "QSLOI/PUNET/NSAUI/TPLEB/RABOR"
    let placements =
      "PLANET=3,1;3,2;2,2;1,2;1,3;1,4"
      + "|ORBIT=4,3;4,4;3,4;2,4;1,4|SUN=0,1;1,1;1,2"
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
