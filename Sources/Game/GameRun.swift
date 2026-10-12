import LetterGrid
import Levels
import Observation

public enum ScoreEvent: Equatable, Sendable {
  case word(String, points: Int)
  case hint(points: Int)
  case newGame
}

public struct GameSnapshot: Equatable, Sendable {
  public var seed: UInt64
  public var levelNumber: Int
  public var score: Int
  public var progress: RoundProgress

  public init(
    seed: UInt64, levelNumber: Int = 1, score: Int = 0, progress: RoundProgress = RoundProgress()
  ) {
    self.seed = seed
    self.levelNumber = levelNumber
    self.score = score
    self.progress = progress
  }
}

@MainActor
@Observable
public final class GameRun: Identifiable {
  public enum Ending: Equatable, Sendable {
    case timeUp
    case everyLevelPlayed
    case levelUnbuilt(Int)
  }

  public private(set) var score: Int
  public private(set) var levelNumber = 1
  public private(set) var round: Round?
  public private(set) var ending: Ending?
  public private(set) var failure: (any Error)?
  public private(set) var known: Set<String>
  public let configuration: GameConfiguration
  public var record: (ScoreEvent) -> Void
  public var changed: () -> Void
  private var plan: LevelPlan

  public init(
    plan: LevelPlan, snapshot: GameSnapshot, known: Set<String> = [],
    record: @escaping (ScoreEvent) -> Void = { _ in }, changed: @escaping () -> Void = {}
  ) {
    self.plan = plan
    self.configuration = plan.configuration
    self.score = snapshot.score
    self.known = known
    self.record = record
    self.changed = changed
    open(levelNumber: snapshot.levelNumber, progress: snapshot.progress)
  }

  public var snapshot: GameSnapshot {
    GameSnapshot(
      seed: plan.seed, levelNumber: levelNumber, score: score,
      progress: round?.progress ?? RoundProgress())
  }

  public var hintsLeft: Int { max(score, 0) / configuration.hintCost }

  public var canUseHint: Bool {
    hintsLeft > 0 && round?.phase == .playing && round?.hintTarget != nil
  }

  public func introduceNextLetter() {
    guard let placement = round?.introduceNextLetter() else { return }
    award(placement)
    changed()
  }

  public func secondPassed() {
    guard round?.secondsLeft != nil else { return }
    round?.secondPassed()
    noteLoss()
    changed()
  }

  public func touch(_ cell: Cell) {
    round?.touch(cell)
  }

  public func drag(to cell: Cell) {
    round?.drag(to: cell)
  }

  public func release() {
    guard let placement = round?.release() else { return }
    award(placement)
    changed()
  }

  public func clearRejection() {
    round?.clearRejection()
  }

  public func useHint() {
    guard canUseHint, round?.reveal() != nil else { return }
    score -= configuration.hintCost
    record(.hint(points: -configuration.hintCost))
    changed()
  }

  public func nextLevel() {
    guard let round, round.phase == .won, ending == nil else { return }
    open(levelNumber: levelNumber + 1, progress: RoundProgress())
    changed()
  }

  public func startOver(with plan: LevelPlan) {
    self.plan = plan
    score = 0
    ending = nil
    failure = nil
    open(levelNumber: 1, progress: RoundProgress())
    record(.newGame)
    changed()
  }

  private func award(_ placement: Placement) {
    let points = placement.word.count * configuration.pointsPerLetter
    score += points
    known.insert(placement.word)
    record(.word(placement.word, points: points))
  }

  private func noteLoss() {
    if round?.phase == .lost {
      ending = .timeUp
    }
  }

  private func open(levelNumber: Int, progress: RoundProgress) {
    self.levelNumber = levelNumber
    guard let level = plan.level(levelNumber) else {
      round = nil
      ending = .everyLevelPlayed
      return
    }
    do {
      round = Round(
        board: try plan.board(for: level),
        directions: configuration.directions,
        seconds: level.seconds,
        introduces: levelNumber == 1,
        progress: progress
      )
      noteLoss()
    } catch {
      round = nil
      failure = error
      ending = .levelUnbuilt(levelNumber)
    }
  }
}
