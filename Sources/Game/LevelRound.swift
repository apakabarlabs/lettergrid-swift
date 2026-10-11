import Levels
import Observation
import WordGrid

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
  public private(set) var secondsLeft: Int
  public private(set) var found: Set<Placement> = []
  public private(set) var introduced: [Cell] = []
  public private(set) var selection: [Cell] = []
  private let directions: [Direction]

  public init(level: Level, board: Board, directions: [Direction], introduces: Bool) {
    self.level = level
    self.board = board
    self.directions = directions
    self.secondsLeft = level.seconds
    self.phase = introduces && !board.placements.isEmpty ? .introducing : .playing
  }

  public var isOver: Bool { phase == .won || phase == .lost }

  public func introduceNextLetter() {
    guard phase == .introducing, let first = board.placements.first else { return }
    if introduced.count < first.cells.count {
      introduced = Array(first.cells.prefix(introduced.count + 1))
    } else {
      found.insert(first)
      introduced = []
      phase = .playing
    }
  }

  public func secondPassed() {
    guard phase == .playing else { return }
    secondsLeft = max(secondsLeft - 1, 0)
    if secondsLeft == 0 {
      selection = []
      phase = .lost
    }
  }

  public func touch(_ cell: Cell) {
    guard phase == .playing else { return }
    selection = [cell]
  }

  public func drag(to cell: Cell) {
    guard phase == .playing, let start = selection.first else { return }
    selection = board.selection(from: start, toward: cell, along: directions)
  }

  public func release() {
    defer { selection = [] }
    guard phase == .playing,
      let placement = board.placements.first(where: { $0.cells == selection }),
      !found.contains(placement)
    else { return }
    found.insert(placement)
    if found.count == board.placements.count {
      phase = .won
    }
  }
}
