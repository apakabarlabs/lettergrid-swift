import Levels
import Observation
import WordGrid

public struct RoundProgress: Codable, Equatable, Sendable {
  public var found: [String]
  public var revealed: [String: Int]

  public init(found: [String] = [], revealed: [String: Int] = [:]) {
    self.found = found
    self.revealed = revealed
  }
}

@MainActor
@Observable
public final class LevelRound {
  public enum Phase: Equatable, Sendable {
    case introducing
    case playing
    case won
    case lost
  }

  public let level: Level
  public let board: Board
  public private(set) var phase: Phase
  public private(set) var secondsLeft: Int?
  public private(set) var found: Set<Placement>
  public private(set) var revealed: [Placement: Int]
  public private(set) var introduced: [Cell] = []
  public private(set) var selection: [Cell] = []
  public private(set) var rejected: [Cell] = []
  private let directions: [Direction]

  public init(
    level: Level, board: Board, directions: [Direction], introduces: Bool,
    progress: RoundProgress = RoundProgress()
  ) {
    self.level = level
    self.board = board
    self.directions = directions
    self.secondsLeft = level.seconds
    let byWord = Dictionary(
      board.placements.map { ($0.word, $0) }, uniquingKeysWith: { first, _ in first })
    self.found = Set(progress.found.compactMap { byWord[$0] })
    self.revealed = Dictionary(
      progress.revealed.compactMap { word, count in byWord[word].map { ($0, count) } },
      uniquingKeysWith: { first, _ in first })
    let startsWithIntroduction = introduces && progress.found.isEmpty && !board.placements.isEmpty
    self.phase = startsWithIntroduction ? .introducing : .playing
    if found.count == board.placements.count, !board.placements.isEmpty {
      phase = .won
    }
  }

  public var isOver: Bool { phase == .won || phase == .lost }

  public var progress: RoundProgress {
    RoundProgress(
      found: board.placements.filter(found.contains).map(\.word),
      revealed: Dictionary(uniqueKeysWithValues: revealed.map { ($0.key.word, $0.value) }))
  }

  public var hintTarget: Placement? {
    let open = board.placements.filter { !found.contains($0) }
    return open.first { revealed[$0, default: 0] == 0 }
      ?? open.first { revealed[$0, default: 0] < $0.word.count - 1 }
  }

  func introduceNextLetter() -> Placement? {
    guard phase == .introducing, let first = board.placements.first else { return nil }
    if introduced.count < first.cells.count {
      introduced = Array(first.cells.prefix(introduced.count + 1))
      return nil
    }
    introduced = []
    phase = .playing
    return record(first)
  }

  func secondPassed() {
    guard phase == .playing, let seconds = secondsLeft else { return }
    secondsLeft = max(seconds - 1, 0)
    if secondsLeft == 0 {
      selection = []
      phase = .lost
    }
  }

  func touch(_ cell: Cell) {
    guard phase == .playing else { return }
    rejected = []
    selection = [cell]
  }

  func drag(to cell: Cell) {
    guard phase == .playing, let start = selection.first else { return }
    selection = board.selection(from: start, toward: cell, along: directions)
  }

  func release() -> Placement? {
    let released = selection
    selection = []
    guard phase == .playing, released.count > 1 else { return nil }
    guard let placement = board.placements.first(where: { $0.cells == released }),
      !found.contains(placement)
    else {
      rejected = released
      return nil
    }
    return record(placement)
  }

  func reveal() -> Placement? {
    guard phase == .playing, let target = hintTarget else { return nil }
    revealed[target, default: 0] += 1
    return target
  }

  func clearRejection() {
    rejected = []
  }

  private func record(_ placement: Placement) -> Placement {
    found.insert(placement)
    if found.count == board.placements.count {
      phase = .won
    }
    return placement
  }
}
