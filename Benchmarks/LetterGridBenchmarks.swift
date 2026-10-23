import Foundation
import LetterGrid

@main
struct LetterGridBenchmarks {
  @MainActor
  static func main() throws {
    boardScans()
    try fallbackBoards()
    hints()
  }

  @MainActor
  private static func boardScans() {
    for side in [16, 32, 64] {
      let board = Board(
        letters: Array(repeating: Array(repeating: Character("A"), count: side), count: side),
        placements: [])
      let dictionary: Set<String> = [String(repeating: "A", count: side) + "X"]
      measure("strayWords side=\(side)", iterations: 3) {
        board.strayWords(of: dictionary, along: Direction.allCases).count
      }
    }
    let side = 16
    let word = String(repeating: "A", count: side)
    let board = Board(
      letters: Array(repeating: Array(word), count: side),
      placements: [Placement(word: word, start: Cell(row: 0, column: 0), direction: .right)])
    measure("strayWords covered side=16", iterations: 3) {
      board.strayWords(of: ["A", "AA", "AAA", "AAAA"], along: Direction.allCases).count
    }
    let row: [Character] = Array(repeating: [Character("a"), "\u{301}", "x"], count: 6).flatMap {
      $0
    }
    let joined = Board(letters: Array(repeating: row, count: side), placements: [])
    measure("strayWords joinedUnicode 18x16", iterations: 3) {
      joined.strayWords(of: ["á", "áx", "x"], along: Direction.allCases).count
    }
  }

  @MainActor
  private static func fallbackBoards() throws {
    for count in [4, 16, 26] {
      let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".prefix(count))
      let weights = Dictionary(uniqueKeysWithValues: alphabet.map { (String($0), 1.0) })
      let generator = BoardGenerator(
        columns: 7, rows: 7, directions: [.right, .down],
        filler: try LetterWeights(weights, sameNeighbour: 0.2), attempts: 0)
      let request = try generator.request(for: ["SUN", "MOON"])
      var seed: UInt64 = 0
      measure("fallback alphabet=\(count)", iterations: 100) {
        seed += 1
        let board = request.board(seed: seed)
        return board.rows + board.letters.flatMap { $0 }.filter { $0 == "A" }.count
      }
    }
  }

  @MainActor
  private static func hints() {
    for length in [32, 128, 512] {
      let word = String(repeating: "A", count: length)
      let placement = Placement(word: word, start: Cell(row: 0, column: 0), direction: .right)
      let board = Board(letters: [Array(word)], placements: [placement])
      let round = Round(
        board: board, directions: [.right], hintOrder: .anyButFirst,
        progress: RoundProgress(revealed: [word: length - 1]))
      measure("hintedCells length=\(length)", iterations: 200) {
        round.hintedCells.reduce(0) { $0 + $1.column }
      }
    }
  }

  @MainActor
  private static func measure(_ name: String, iterations: Int, operation: () -> Int) {
    var checksum = operation()
    let samples = (0..<5).map { _ in
      let duration = ContinuousClock().measure {
        for _ in 0..<iterations { checksum &+= operation() }
      }.components
      return (Double(duration.seconds) + Double(duration.attoseconds) / 1e18) * 1000
        / Double(iterations)
    }.sorted()
    let median = String(format: "%.6f", samples[2])
    let line = "\(name): \(median) ms/op; checksum=\(checksum)\n"
    FileHandle.standardOutput.write(Data(line.utf8))
  }
}
