import WordGrid
import Yams

public struct GameConfiguration: Decodable, Sendable {
  public enum Failure: Error, Equatable {
    case notPositive(String)
    case invalidRamp(String)
    case noDirections
  }

  public let secondsPerLevel: Int
  public let showWordList: Bool
  public let directions: [Direction]
  public let columns: Ramp
  public let rows: Ramp
  public let wordsPerLevel: Ramp
  public let minWordLength: Int
  public let clusterSize: Int
  public let letters: [String: Double]

  public static func decode(_ yaml: String) throws -> GameConfiguration {
    let configuration = try YAMLDecoder().decode(GameConfiguration.self, from: yaml)
    try configuration.validate()
    return configuration
  }

  public func filler() throws -> LetterWeights {
    try LetterWeights(letters)
  }

  private func validate() throws {
    guard !directions.isEmpty else { throw Failure.noDirections }
    for (name, value) in [
      ("seconds_per_level", secondsPerLevel), ("min_word_length", minWordLength),
      ("cluster_size", clusterSize),
    ] {
      guard value > 0 else { throw Failure.notPositive(name) }
    }
    for (name, ramp) in [("columns", columns), ("rows", rows), ("words_per_level", wordsPerLevel)] {
      guard ramp.isValid, ramp.first > 0, ramp.last > 0 else { throw Failure.invalidRamp(name) }
    }
    _ = try filler()
  }

  private enum CodingKeys: String, CodingKey {
    case secondsPerLevel = "seconds_per_level"
    case showWordList = "show_word_list"
    case directions
    case columns
    case rows
    case wordsPerLevel = "words_per_level"
    case minWordLength = "min_word_length"
    case clusterSize = "cluster_size"
    case letters
  }
}

public struct WordList: Decodable, Sendable {
  public let words: [String]

  public static func decode(_ yaml: String) throws -> WordList {
    try YAMLDecoder().decode(WordList.self, from: yaml)
  }
}
