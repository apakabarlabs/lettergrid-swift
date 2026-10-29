import Foundation
import LetterGrid

@MainActor
enum BoundedBoards {
  struct Input {
    let words: [String]
    let request: BoardRequest
  }

  static func run(words: Set<String>, rules: [WordRule], weights: LetterWeights) throws {
    let workload = TurnedWorkload(words: words, rules: rules, weights: weights)
    let generator = workload.generator
    let firstRule = rules.last
    let samples = try inputs(workload)
    for (index, sample) in samples.enumerated() {
      FileHandle.standardOutput.write(
        Data("bounded input=\(index); words=\(sample.words.joined(separator: " "))\n".utf8))
    }
    precondition(samples.count >= 20, "Too few synthetic levels fit the bounded board")
    let dictionary = BoardDictionary(words)
    try LetterGridBenchmarks.measureWorst(
      "bounded request 7x7 firstTurns=3 rules=28", iterations: samples.count
    ) { index in
      try generator.request(for: samples[index].words, firstRule: firstRule).words.count
    }
    LetterGridBenchmarks.measureWorst(
      "bounded board 7x7 firstTurns=3 rules=28 dictionary=7000", iterations: samples.count
    ) { index in
      samples[index].request.board(seed: UInt64(index + 1), dictionary: dictionary).rows
    }
  }

  static func inputs(_ workload: TurnedWorkload) throws -> [Input] {
    let generator = workload.generator
    var inputs: [Input] = []
    for words in TurnedBoards.levels(in: workload.words) {
      do {
        inputs.append(
          Input(
            words: words,
            request: try generator.request(for: words, firstRule: workload.rules.last)))
      } catch BoardGenerator.Failure.noRoom, BoardGenerator.Failure.unsettled {
        continue
      }
    }
    return inputs
  }
}
