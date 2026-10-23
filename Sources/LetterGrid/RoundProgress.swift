import Foundation

public struct RoundProgress: Equatable, Sendable {
  public enum Failure: LocalizedError, Equatable {
    case unknownWord(String)
    case duplicateFoundWord(String)
    case invalidRevealCount(word: String, count: Int)
    case negativeSeconds(Int)

    public var errorDescription: String? {
      switch self {
      case .unknownWord(let word): "The saved word \(word) is not on this board."
      case .duplicateFoundWord(let word): "The saved word \(word) is marked found more than once."
      case .invalidRevealCount(let word, let count):
        "The saved revealed-letter count \(count) is invalid for \(word)."
      case .negativeSeconds(let seconds): "The saved countdown has negative seconds: \(seconds)."
      }
    }
  }

  public var found: [String]
  public var revealed: [String: Int]
  public var secondsLeft: Int?
  public var isLost: Bool

  public init(
    found: [String] = [], revealed: [String: Int] = [:], secondsLeft: Int? = nil,
    isLost: Bool = false
  ) {
    self.found = found
    self.revealed = revealed
    self.secondsLeft = secondsLeft
    self.isLost = isLost
  }

  public func validate(for board: Board) throws {
    let words = Dictionary(uniqueKeysWithValues: board.placements.map { ($0.word, $0.word.count) })
    var seen: Set<String> = []
    for word in found {
      guard words[word] != nil else { throw Failure.unknownWord(word) }
      guard seen.insert(word).inserted else { throw Failure.duplicateFoundWord(word) }
    }
    for (word, count) in revealed {
      guard let length = words[word] else { throw Failure.unknownWord(word) }
      guard (0..<length).contains(count) else {
        throw Failure.invalidRevealCount(word: word, count: count)
      }
    }
    if let secondsLeft, secondsLeft < 0 { throw Failure.negativeSeconds(secondsLeft) }
  }
}
