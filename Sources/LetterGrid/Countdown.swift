@MainActor
public struct Countdown {
  public typealias Sleep = @Sendable (Duration) async throws -> Void

  private let sleep: Sleep

  public init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
    self.sleep = sleep
  }

  public func run(
    _ round: Round, secondsPerLetter: Double, introduce: () -> Void, tick: () -> Void
  ) async {
    do {
      while round.phase == .introducing {
        try await sleep(.seconds(secondsPerLetter))
        introduce()
      }
      while round.phase == .playing, round.secondsLeft != nil {
        try await sleep(.seconds(1))
        tick()
      }
    } catch {
      return
    }
  }
}
