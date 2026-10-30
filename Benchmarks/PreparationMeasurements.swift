import Foundation
import LetterGrid
import Yams

enum PreparationMeasurements {
  private struct Rule: Decodable {
    let directions: [Direction]
    let turns: Int

    var value: WordRule { WordRule(startDirections: directions, turns: turns) }
  }

  private struct Input: Decodable {
    var name: String
    let columns: Int
    let rows: Int
    let maxRows: Int?
    let rules: [Rule]
    let leadingRules: [Rule]?
    var weights: [String: Double]
    let sameNeighbour: Double?
    let downWords: [Int]
    var words: [[String]]
    let sampling: [Sampling]?

    var generator: BoardGenerator {
      get throws {
        guard downWords.count == 2, downWords[0] <= downWords[1] else {
          throw Failure.quota(name)
        }
        return BoardGenerator(
          columns: columns, rows: rows, maxRows: maxRows, rules: rules.map(\.value),
          filler: try LetterWeights(weights, sameNeighbour: sameNeighbour ?? 1),
          downWords: downWords[0]...downWords[1])
      }
    }
  }

  private struct Vocabulary: Decodable {
    let words: [Entry]
  }

  private struct Entry: Decodable { let word: String }

  private enum SamplingOrder: String, Decodable { case random, adjacent }

  private struct Sampling: Decodable {
    let count: Int
    let minimumLength: Int
    let maximumLength: Int
    let order: SamplingOrder
    let seed: UInt64
  }

  private struct Samples {
    var placement: [Double] = []
    var fill: [Double] = []
    var repacking: [Double] = []
    var placed = 0
    var refused = 0
    var unsettled = 0
    var fillFailures = 0

    func report(_ name: String) {
      let placementTotal = placement.reduce(0, +)
      let fillTotal = fill.reduce(0, +)
      let repackingTotal = repacking.reduce(0, +)
      let share =
        fillTotal
        / max(
          placementTotal + repackingTotal + fillTotal, Double.leastNonzeroMagnitude)
      let line =
        "\(name): inputs=\(placement.count), placed=\(placed), noRoom=\(refused), "
        + "placementUnsettled=\(unsettled), fillFailures=\(fillFailures); "
        + "placement_ms=\(placementTotal), repacking_ms=\(repackingTotal), "
        + "fill_ms=\(fillTotal), fill_share=\(share); "
        + "placement_max_ms=\(placement.max() ?? 0), fill_max_ms=\(fill.max() ?? 0)\n"
      FileHandle.standardOutput.write(Data(line.utf8))
    }
  }

  enum Failure: Error {
    case arguments
    case quota(String)
    case empty
  }

  static func run(_ arguments: [String]) throws {
    guard arguments.count == 1 else { throw Failure.arguments }
    let inputs = try YAMLDecoder().decode(
      [Input].self, from: String(contentsOfFile: arguments[0], encoding: .utf8))
    try measure(inputs)
  }

  static func vocabulary(_ arguments: [String]) throws {
    guard (2...3).contains(arguments.count), arguments.count == 2 || arguments[2] == "--fold" else {
      throw Failure.arguments
    }
    let raw = try YAMLDecoder().decode(
      Vocabulary.self, from: String(contentsOfFile: arguments[1], encoding: .utf8))
    let words = Set(
      raw.words.map { entry in
        let word =
          arguments.count == 3
          ? entry.word.folding(
            options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
          : entry.word
        return word.cellUppercased
      })
    let name = URL(fileURLWithPath: arguments[1]).lastPathComponent
    let templates = try YAMLDecoder().decode(
      [Input].self, from: String(contentsOfFile: arguments[0], encoding: .utf8))
    let inputs = try templates.flatMap { try sampled($0, vocabulary: words, name: name) }
    try measure(inputs)
  }

  private static func sampled(
    _ template: Input, vocabulary: Set<String>, name: String
  ) throws -> [Input] {
    guard let samples = template.sampling else { throw Failure.arguments }
    let weights = Dictionary(
      vocabulary.joined().filter(\.isLetter).map { (String($0), 1.0) }, uniquingKeysWith: +)
    return try samples.map { sampling in
      guard sampling.count > 0,
        sampling.minimumLength > 0, sampling.maximumLength >= sampling.minimumLength
      else { throw Failure.arguments }
      let pool = vocabulary.filter {
        (sampling.minimumLength...sampling.maximumLength).contains($0.count)
      }.sorted()
      guard pool.count >= sampling.count + 2 else { throw Failure.empty }
      var input = template
      input.name = "\(name) \(template.name) \(sampling.order.rawValue)"
      input.weights = weights
      var random = SeededRandom(seed: sampling.seed)
      input.words = (0..<sampling.count).map { index in
        if sampling.order == .random { return Array(random.shuffled(pool).prefix(3)) }
        let start = index * (pool.count - 3) / max(1, sampling.count - 1)
        return Array(pool[start..<(start + 3)])
      }
      return input
    }
  }

  private static func measure(_ inputs: [Input]) throws {
    guard !inputs.isEmpty, inputs.allSatisfy({ !$0.words.isEmpty }) else { throw Failure.empty }
    for input in inputs {
      let generator = try input.generator
      let leading = input.leadingRules?.map(\.value) ?? []
      var samples = Samples()
      for words in input.words {
        let start = ContinuousClock.now
        let request: BoardRequest
        do {
          request = try generator.placementRequest(for: words, leadingRules: leading)
          samples.placed += 1
        } catch BoardGenerator.Failure.noRoom {
          samples.refused += 1
          samples.placement.append(milliseconds(since: start))
          continue
        } catch BoardGenerator.Failure.unsettled {
          samples.unsettled += 1
          samples.placement.append(milliseconds(since: start))
          continue
        }
        samples.placement.append(milliseconds(since: start))
        var repacking = Duration.zero
        var filling = Duration.zero
        do {
          _ = try generator.finishPreparation(request) { packingTime, fillTime in
            repacking += packingTime
            filling += fillTime
          }
        } catch BoardGenerator.Failure.unsettled {
          samples.fillFailures += 1
        }
        samples.repacking.append(milliseconds(repacking))
        samples.fill.append(milliseconds(filling))
      }
      samples.report(input.name)
    }
  }

  private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
    milliseconds(start.duration(to: .now))
  }

  private static func milliseconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) * 1000 + Double(value.attoseconds) / 1e15
  }
}
