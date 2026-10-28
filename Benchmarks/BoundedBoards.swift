import Foundation
import LetterGrid

@MainActor
enum BoundedBoards {
  private struct Sample {
    let words: [String]
    let previous: BoardRequest
    let current: BoardRequest
  }

  static func run(words: Set<String>, rules: [WordRule], weights: LetterWeights) throws {
    func generator(_ version: BoardGenerationVersion) -> BoardGenerator {
      BoardGenerator(
        columns: 7, rows: 7, maxRows: 7, rules: rules, filler: weights,
        downWords: 1...2, attempts: 4, fillsPerAttempt: 10, generationVersion: version)
    }
    let previous = generator(.v0p18)
    let current = generator(.v0p19)
    let firstRule = rules.last
    var samples: [Sample] = []
    for words in TurnedBoards.levels(in: words) {
      let request: BoardRequest
      do {
        request = try previous.request(for: words, firstRule: firstRule)
      } catch BoardGenerator.Failure.noRoom {
        continue
      }
      samples.append(
        Sample(
          words: words, previous: request,
          current: try current.request(for: words, firstRule: firstRule)))
    }
    precondition(samples.count >= 20, "Too few synthetic levels fit the bounded board")
    let dictionary = BoardDictionary(words)
    for (name, generator, requests) in [
      ("0.18", previous, samples.map(\.previous)),
      ("0.19", current, samples.map(\.current)),
    ] {
      try LetterGridBenchmarks.measureWorst(
        "bounded request \(name) 7x7 firstTurns=3 rules=28", iterations: samples.count
      ) { index in
        try generator.request(for: samples[index].words, firstRule: firstRule).words.count
      }
      LetterGridBenchmarks.measureWorst(
        "bounded board \(name) 7x7 firstTurns=3 rules=28 dictionary=7000", iterations: samples.count
      ) { index in
        requests[index].board(seed: UInt64(index + 1), dictionary: dictionary).rows
      }
    }
  }
}
