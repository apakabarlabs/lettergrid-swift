import Foundation
import LetterGrid

@MainActor
enum BoundedBoards {
  struct Input {
    let words: [String]
    let previous: BoardRequest
  }

  private struct Sample {
    let words: [String]
    let previous: BoardRequest
    let current: BoardRequest
  }

  static func run(words: Set<String>, rules: [WordRule], weights: LetterWeights) throws {
    let workload = TurnedWorkload(words: words, rules: rules, weights: weights)
    let previous = workload.generator(.v0p18)
    let current = workload.generator(.v0p19)
    let firstRule = rules.last
    let samples = try inputs(workload).map {
      Sample(
        words: $0.words, previous: $0.previous,
        current: try current.request(for: $0.words, firstRule: firstRule))
    }
    for (index, sample) in samples.enumerated() {
      FileHandle.standardOutput.write(
        Data("bounded input=\(index); words=\(sample.words.joined(separator: " "))\n".utf8))
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

  static func inputs(_ workload: TurnedWorkload) throws -> [Input] {
    let generator = workload.generator(.v0p18)
    var inputs: [Input] = []
    for words in TurnedBoards.levels(in: workload.words) {
      do {
        inputs.append(
          Input(
            words: words,
            previous: try generator.request(for: words, firstRule: workload.rules.last)))
      } catch BoardGenerator.Failure.noRoom {
        continue
      }
    }
    return inputs
  }
}
