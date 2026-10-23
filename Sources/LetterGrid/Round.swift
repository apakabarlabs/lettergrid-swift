import Foundation
import Observation

public enum HintOrder: String, Sendable, Decodable {
  case fromStart = "from_start"
  case anyButFirst = "any_but_first"

  func letterIndices(of word: String) -> [Int] {
    switch self {
    case .fromStart:
      return Array(0..<word.count)
    case .anyButFirst:
      let seed = word.unicodeScalars.reduce(UInt64(0xCBF2_9CE4_8422_2325)) {
        ($0 ^ UInt64($1.value)) &* 0x100_0000_01B3
      }
      var random = SeededRandom(seed: seed)
      return Array(1..<max(word.count, 1)).shuffled(using: &random)
    }
  }
}

@MainActor
@Observable
public final class Round: Identifiable {
  public enum Failure: LocalizedError, Equatable {
    case unselectableWord(String)

    public var errorDescription: String? {
      switch self {
      case .unselectableWord(let word): "The enabled directions cannot select the word \(word)."
      }
    }
  }

  public enum Phase: Equatable, Sendable {
    case introducing
    case playing
    case won
    case lost
  }

  public nonisolated let id = UUID()
  public let board: Board
  public let showsFirstWord: Bool
  public let hintOrder: HintOrder
  public private(set) var phase: Phase
  public private(set) var secondsLeft: Int?
  public private(set) var found: Set<Placement>
  public private(set) var revealed: [Placement: Int]
  public private(set) var introduced: [Cell] = []
  public private(set) var selection: [Cell] = []
  public private(set) var rejected: [Cell] = []
  private let directions: [Direction]

  public init(
    board: Board, directions: [Direction], seconds: Int? = nil, introduces: Bool = false,
    hintOrder: HintOrder = .fromStart, progress: RoundProgress = RoundProgress()
  ) {
    precondition(seconds.map { $0 >= 0 } ?? true, "Round seconds must be nonnegative")
    do {
      try progress.validate(for: board)
      try Self.validateDirections(directions, for: board)
    } catch {
      preconditionFailure("Invalid round progress: \(error.localizedDescription)")
    }
    self.board = board
    self.directions = directions
    self.hintOrder = hintOrder
    self.showsFirstWord = introduces && !board.placements.isEmpty
    self.secondsLeft = seconds.map { progress.secondsLeft ?? $0 }
    let byWord = Dictionary(
      board.placements.map { ($0.word, $0) }, uniquingKeysWith: { first, _ in first })
    self.found = Set(progress.found.compactMap { byWord[$0] })
    self.revealed = Dictionary(
      progress.revealed.compactMap { word, count in byWord[word].map { ($0, count) } },
      uniquingKeysWith: { first, _ in first })
    let startsWithIntroduction = introduces && progress.found.isEmpty && !board.placements.isEmpty
    self.phase = startsWithIntroduction ? .introducing : .playing
    if found.count == board.placements.count {
      phase = .won
    } else if progress.isLost || secondsLeft == 0 {
      phase = .lost
    }
  }

  public convenience init(
    restoring progress: RoundProgress, board: Board, directions: [Direction],
    seconds: Int? = nil, introduces: Bool = false, hintOrder: HintOrder = .fromStart
  ) throws {
    if let seconds, seconds < 0 { throw RoundProgress.Failure.negativeSeconds(seconds) }
    try progress.validate(for: board)
    try Self.validateDirections(directions, for: board)
    self.init(
      board: board, directions: directions, seconds: seconds, introduces: introduces,
      hintOrder: hintOrder, progress: progress)
  }

  private static func validateDirections(_ directions: [Direction], for board: Board) throws {
    for placement in board.placements {
      guard
        directions.contains(placement.direction)
          || (placement.isPalindrome && directions.contains(placement.direction.opposite))
      else { throw Failure.unselectableWord(placement.word) }
    }
  }

  public var isOver: Bool { phase == .won || phase == .lost }

  public var progress: RoundProgress {
    RoundProgress(
      found: board.placements.filter(found.contains).map(\.word),
      revealed: Dictionary(uniqueKeysWithValues: revealed.map { ($0.key.word, $0.value) }),
      secondsLeft: secondsLeft,
      isLost: phase == .lost)
  }

  public var hintTarget: Placement? {
    let open = board.placements.filter { !found.contains($0) }
    return open.first { revealed[$0, default: 0] == 0 && hintLimit(of: $0) > 0 }
      ?? open.first { revealed[$0, default: 0] < hintLimit(of: $0) }
  }

  public var hintedCells: [Cell] {
    board.placements.filter { !found.contains($0) }.flatMap { placement in
      revealedIndices(of: placement).map { placement.cells[$0] }
    }
  }

  public func shownLetters(of placement: Placement) -> [Character?] {
    let letters = Array(placement.word)
    if found.contains(placement) { return letters }
    let opened = Set(revealedIndices(of: placement))
    return letters.indices.map { opened.contains($0) ? letters[$0] : nil }
  }

  public func introduceNextLetter() -> Placement? {
    guard phase == .introducing, let first = board.placements.first else { return nil }
    if introduced.count < first.cells.count {
      introduced = Array(first.cells.prefix(introduced.count + 1))
      return nil
    }
    introduced = []
    phase = .playing
    return record(first)
  }

  public func secondPassed() {
    guard phase == .playing, let seconds = secondsLeft else { return }
    secondsLeft = max(seconds - 1, 0)
    if secondsLeft == 0 {
      selection = []
      phase = .lost
    }
  }

  public func touch(_ cell: Cell) {
    guard phase == .playing, board.contains(cell) else { return }
    rejected = []
    selection = [cell]
  }

  public func drag(to cell: Cell) {
    guard phase == .playing, let start = selection.first else { return }
    selection = board.selection(from: start, toward: cell, along: directions)
  }

  public func release() -> Placement? {
    let released = selection
    selection = []
    guard phase == .playing, released.count > 1 else { return nil }
    guard let placement = board.placements.first(where: { $0.reads(released) }),
      !found.contains(placement)
    else {
      rejected = released
      return nil
    }
    return record(placement)
  }

  public func reveal() -> Placement? {
    guard phase == .playing, let target = hintTarget else { return nil }
    revealed[target, default: 0] += 1
    return target
  }

  public func clearRejection() {
    rejected = []
  }

  private func hintLimit(of placement: Placement) -> Int {
    min(hintOrder.letterIndices(of: placement.word).count, placement.word.count - 1)
  }

  private func revealedIndices(of placement: Placement) -> [Int] {
    Array(hintOrder.letterIndices(of: placement.word).prefix(revealed[placement, default: 0]))
  }

  private func record(_ placement: Placement) -> Placement {
    found.insert(placement)
    if found.count == board.placements.count {
      phase = .won
    }
    return placement
  }
}
