import WordGrid
import Yams

public struct GridStep: Decodable, Equatable, Sendable {
  public let columns: Int
  public let rows: Int
  public let words: Int
  public let levels: Int?
  public let seconds: Int?

  public init(columns: Int, rows: Int, words: Int, levels: Int?, seconds: Int? = nil) {
    self.columns = columns
    self.rows = rows
    self.words = words
    self.levels = levels
    self.seconds = seconds
  }
}

public struct GameConfiguration: Decodable, Sendable {
  public enum Failure: Error, Equatable {
    case notPositive(String)
    case noSteps
    case endlessStepBeforeTheLast
    case noDirections
    case fewerAllowedThanRequired(String)
  }

  public let steps: [GridStep]
  public let directions: [Direction]
  public let minVerticalWords: Int
  public let maxVerticalWords: Int
  public let minWordLength: Int
  public let clusterSize: Int
  public let letters: [String: Double]
  public let introSecondsPerLetter: Double
  public let pointsPerLetter: Int
  public let hintCost: Int
  public let hintsPerLevel: Int
  public let rejectionSeconds: Double

  public init(
    steps: [GridStep],
    directions: [Direction],
    minVerticalWords: Int,
    maxVerticalWords: Int,
    minWordLength: Int,
    clusterSize: Int,
    letters: [String: Double],
    introSecondsPerLetter: Double,
    pointsPerLetter: Int,
    hintCost: Int,
    hintsPerLevel: Int,
    rejectionSeconds: Double
  ) throws {
    self.steps = steps
    self.directions = directions
    self.minVerticalWords = minVerticalWords
    self.maxVerticalWords = maxVerticalWords
    self.minWordLength = minWordLength
    self.clusterSize = clusterSize
    self.letters = letters
    self.introSecondsPerLetter = introSecondsPerLetter
    self.pointsPerLetter = pointsPerLetter
    self.hintCost = hintCost
    self.hintsPerLevel = hintsPerLevel
    self.rejectionSeconds = rejectionSeconds
    try validate()
  }

  public static func decode(_ yaml: String) throws -> GameConfiguration {
    let configuration = try YAMLDecoder().decode(GameConfiguration.self, from: yaml)
    try configuration.validate()
    return configuration
  }

  public func filler() throws -> LetterWeights {
    try LetterWeights(letters)
  }

  public func step(at level: Int) -> GridStep? {
    var first = 1
    for step in steps {
      guard let levels = step.levels else { return step }
      if level < first + levels { return step }
      first += levels
    }
    return nil
  }

  private func validate() throws {
    guard !steps.isEmpty else { throw Failure.noSteps }
    guard steps.dropLast().allSatisfy({ $0.levels != nil }) else {
      throw Failure.endlessStepBeforeTheLast
    }
    guard !directions.isEmpty else { throw Failure.noDirections }
    for step in steps {
      for (name, value) in [
        ("columns", step.columns), ("rows", step.rows), ("words", step.words),
        ("levels", step.levels ?? 1), ("seconds", step.seconds ?? 1),
      ] where value <= 0 {
        throw Failure.notPositive(name)
      }
    }
    for (name, value) in [
      ("min_word_length", minWordLength), ("cluster_size", clusterSize),
      ("points_per_letter", pointsPerLetter),
    ] where value <= 0 {
      throw Failure.notPositive(name)
    }
    for (name, value) in [
      ("hint_cost", hintCost), ("hints_per_level", hintsPerLevel),
      ("min_vertical_words", minVerticalWords), ("max_vertical_words", maxVerticalWords),
    ] where value < 0 {
      throw Failure.notPositive(name)
    }
    guard minVerticalWords <= maxVerticalWords else {
      throw Failure.fewerAllowedThanRequired("vertical_words")
    }
    for (name, value) in [
      ("intro_seconds_per_letter", introSecondsPerLetter), ("rejection_seconds", rejectionSeconds),
    ] where value <= 0 {
      throw Failure.notPositive(name)
    }
    _ = try filler()
  }

  private enum CodingKeys: String, CodingKey {
    case steps
    case directions
    case minVerticalWords = "min_vertical_words"
    case maxVerticalWords = "max_vertical_words"
    case minWordLength = "min_word_length"
    case clusterSize = "cluster_size"
    case letters
    case introSecondsPerLetter = "intro_seconds_per_letter"
    case pointsPerLetter = "points_per_letter"
    case hintCost = "hint_cost"
    case hintsPerLevel = "hints_per_level"
    case rejectionSeconds = "rejection_seconds"
  }
}

public struct WordEntry: Decodable, Equatable, Sendable {
  public let word: String
  public let sense: String?
  public let grammar: String
  public let level: String

  public init(word: String, sense: String? = nil, grammar: String = "", level: String = "A1") {
    self.word = word
    self.sense = sense
    self.grammar = grammar
    self.level = level
  }

  public var spelling: String { word.uppercased() }

  public var isOneWord: Bool {
    !word.isEmpty
      && word.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
  }
}

public struct WordList: Decodable, Sendable {
  public let words: [WordEntry]

  public static func decode(_ yaml: String) throws -> WordList {
    try YAMLDecoder().decode(WordList.self, from: yaml)
  }
}
