@MainActor
public struct Countdown {
  public typealias Sleep = @Sendable (Duration) async throws -> Void

  private let sleep: Sleep

  public init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
    self.sleep = sleep
  }

  public func run(_ game: GameRun) async {
    guard let round = game.round else { return }
    do {
      while round.phase == .introducing {
        try await sleep(.seconds(game.configuration.introSecondsPerLetter))
        game.introduceNextLetter()
      }
      while round.phase == .playing, round.secondsLeft != nil {
        try await sleep(.seconds(1))
        game.secondPassed()
      }
    } catch {
      return
    }
  }

  public func fadeRejection(of game: GameRun) async {
    do {
      try await sleep(.seconds(game.configuration.rejectionSeconds))
    } catch {
      return
    }
    game.clearRejection()
  }
}
