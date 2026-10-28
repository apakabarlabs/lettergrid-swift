import Foundation
import LetterGrid

@MainActor
enum TurnedBoards {
  private struct Lcg {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
  }

  private static let letters = Array(
    "EEEEEEEEEEEETTTTTTTTTAAAAAAAAOOOOOOOIIIIIIINNNNNNNSSSSSSHHHHHHRRRRRRDDDDLLLLCCCUUUMMWFGYPB")
  private static let groups: [[Direction]] = [
    [.right, .down], [.downRight], [.downLeft], [.left], [.up], [.upLeft], [.upRight],
  ]

  static func run() throws {
    let words = try vocabulary()
    let dictionary = BoardDictionary(words)
    let rules = (0...3).flatMap { turns in
      groups.map { WordRule(startDirections: $0, turns: turns) }
    }
    let weights = Dictionary(letters.map { (String($0), 1.0) }, uniquingKeysWith: +)
    let generator = BoardGenerator(
      columns: 7, rows: 7, rules: rules, filler: try LetterWeights(weights, sameNeighbour: 0.2),
      downWords: 1...2, attempts: 4, fillsPerAttempt: 10)
    try measure(generator: generator, words: words, dictionary: dictionary)
    try BoundedBoards.run(
      words: words, rules: rules, weights: LetterWeights(weights, sameNeighbour: 0.2))
  }

  private static func vocabulary() throws -> Set<String> {
    var random = Lcg(state: 7)
    var words: Set<String> = []
    if let path = ProcessInfo.processInfo.environment["LETTERGRID_BENCH_WORDS"] {
      let text = try String(contentsOfFile: path, encoding: .utf8)
      words = Set(text.split(separator: "\n").map { String($0).cellUppercased })
    }
    while words.count < 7_000 {
      let length = 3 + random.next(7)
      words.insert(String((0..<length).map { _ in letters[random.next(letters.count)] }))
    }
    return words
  }

  private static func measure(
    generator: BoardGenerator, words: Set<String>, dictionary: BoardDictionary
  ) throws {
    var accepted: [[String]] = []
    for level in levels(in: words) {
      do {
        _ = try generator.request(for: level)
        accepted.append(level)
      } catch BoardGenerator.Failure.noRoom {
        continue
      }
    }
    precondition(accepted.count >= 20, "Too few synthetic levels fit the board")
    try LetterGridBenchmarks.measureWorst(
      "turned request minimum=7x7 rules=28", iterations: accepted.count
    ) { index in
      try generator.request(for: accepted[index]).words.count
    }
    var index = 0
    try LetterGridBenchmarks.measure(
      "turned request minimum=7x7 rules=28", iterations: accepted.count
    ) {
      let request = try generator.request(for: accepted[index % accepted.count])
      index += 1
      return request.words.count
    }
    let requests = try accepted.map { try generator.request(for: $0) }
    LetterGridBenchmarks.measureWorst(
      "turned board rules=28 dictionary=7000", iterations: requests.count
    ) { index in
      requests[index].board(seed: UInt64(index + 1), dictionary: dictionary).rows
    }
    let fallbacks = fallbackCount(requests, dictionary: dictionary)
    FileHandle.standardOutput.write(
      Data("turned fallbacks: \(fallbacks) of \(requests.count)\n".utf8))
    var seed: UInt64 = 0
    LetterGridBenchmarks.measure(
      "turned board minimum=7x7 rules=28 dictionary=7000", iterations: requests.count
    ) {
      seed += 1
      let board = requests[Int(seed) % requests.count].board(seed: seed, dictionary: dictionary)
      return board.rows
    }
  }

  static func levels(in words: Set<String>) -> [[String]] {
    let pool = words.filter { (5...7).contains($0.count) }.sorted()
    return (0..<30).map { level in
      let start = level * 3
      return (0..<3).map { offset in pool[(start + offset) % pool.count] }
    }
  }

  private static func fallbackCount(
    _ requests: [BoardRequest], dictionary: BoardDictionary
  ) -> Int {
    requests.enumerated().filter { offset, request in
      let board = request.board(seed: UInt64(offset + 1), dictionary: dictionary)
      let used = Set(board.placements.flatMap(\.cells))
      let wordLetters = Set(request.words.joined())
      return (0..<board.rows).allSatisfy { row in
        (0..<board.columns).allSatisfy { column in
          let cell = Cell(row: row, column: column)
          return used.contains(cell) || !wordLetters.contains(board[cell])
        }
      }
    }.count
  }
}
