import Foundation

@MainActor
public struct Countdown {
  public enum Failure: LocalizedError, Equatable {
    case invalidInterval
    case noIntroductionProgress
    case noClockProgress

    public var errorDescription: String? {
      switch self {
      case .invalidInterval: "The introduction interval must be a positive, representable duration."
      case .noIntroductionProgress: "The introduction callback did not advance the round."
      case .noClockProgress: "The tick callback did not advance the round countdown."
      }
    }
  }

  public typealias Sleep = @Sendable (Duration) async throws -> Void

  private let sleep: Sleep

  public init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
    self.sleep = sleep
  }

  public func run(
    _ round: Round, secondsPerLetter: Double, introduce: () -> Void, tick: () -> Void
  ) async throws {
    guard let interval = SleepInterval(seconds: secondsPerLetter) else {
      throw Failure.invalidInterval
    }
    do {
      while round.phase == .introducing {
        try Task.checkCancellation()
        try await sleep(interval.duration)
        try Task.checkCancellation()
        guard round.phase == .introducing else { break }
        let before = round.introduced
        introduce()
        guard round.phase != .introducing || round.introduced != before else {
          throw Failure.noIntroductionProgress
        }
      }
      while round.phase == .playing, round.secondsLeft != nil {
        try Task.checkCancellation()
        try await sleep(.seconds(1))
        try Task.checkCancellation()
        guard round.phase == .playing, round.secondsLeft != nil else { break }
        let before = round.secondsLeft
        tick()
        guard round.phase != .playing || round.secondsLeft != before else {
          throw Failure.noClockProgress
        }
      }
    } catch is CancellationError {
      return
    }
  }
}
