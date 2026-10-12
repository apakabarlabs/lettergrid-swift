import LetterGrid

extension Countdown {
  public func run(_ game: GameRun) async {
    guard let round = game.round else { return }
    await run(
      round, secondsPerLetter: game.configuration.introSecondsPerLetter,
      introduce: game.introduceNextLetter, tick: game.secondPassed)
  }
}
