import Levels
import Observation

@MainActor
@Observable
public final class GameRun: Identifiable {
  public enum Ending: Equatable, Sendable {
    case timeUp
    case gaveUp
    case everyLevelPlayed
    case levelUnbuilt(Int)
  }

  public private(set) var score = 0
  public private(set) var round: LevelRound?
  public private(set) var ending: Ending?
  public private(set) var failure: (any Error)?
  private let plan: LevelPlan

  public init(plan: LevelPlan) {
    self.plan = plan
    open(levelNumber: 1)
  }

  public var showsWordList: Bool { plan.configuration.showWordList }

  public func roundEnded() {
    guard let round, ending == nil else { return }
    switch round.phase {
    case .won: score += round.secondsLeft
    case .lost: ending = .timeUp
    case .introducing, .playing: break
    }
  }

  public func nextLevel() {
    guard let round, round.phase == .won, ending == nil else { return }
    open(levelNumber: round.level.number + 1)
  }

  public func giveUp() {
    guard ending == nil else { return }
    ending = .gaveUp
  }

  private func open(levelNumber: Int) {
    guard let level = plan.level(levelNumber) else {
      ending = .everyLevelPlayed
      return
    }
    do {
      round = LevelRound(
        level: level,
        board: try plan.board(for: level),
        directions: plan.configuration.directions,
        introduces: levelNumber == 1
      )
    } catch {
      failure = error
      ending = .levelUnbuilt(levelNumber)
    }
  }
}
