@MainActor
public struct Countdown {
  public typealias Sleep = @Sendable (Duration) async throws -> Void

  private let introPerLetter: Duration
  private let sleep: Sleep

  public init(
    introSecondsPerLetter: Double,
    sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
  ) {
    self.introPerLetter = .seconds(introSecondsPerLetter)
    self.sleep = sleep
  }

  public func run(_ round: LevelRound) async {
    do {
      while round.phase == .introducing {
        try await sleep(introPerLetter)
        round.introduceNextLetter()
      }
      while round.phase == .playing {
        try await sleep(.seconds(1))
        round.secondPassed()
      }
    } catch {
      return
    }
  }
}
