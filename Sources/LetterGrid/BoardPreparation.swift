import Foundation

extension BoardGenerator {
  func placementRequest(for words: [String], firstRule: WordRule?) throws -> BoardRequest {
    try validateConfiguration()
    guard firstRule.map(enables) ?? true else { throw Failure.invalidConfiguration }
    return try checkedTargets(for: words, leadingRules: firstRule.map { [$0] } ?? [])
  }

  package func placementRequest(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    try validateConfiguration()
    guard leadingRules.allSatisfy(enables) else { throw Failure.invalidConfiguration }
    return try checkedTargets(for: words, leadingRules: leadingRules)
  }

  private func checkedTargets(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let words = words.map(\.cellUppercased)
    var targets = self
    targets.requiresRunFreeTargets = true
    let request: BoardRequest
    do {
      request = try targets.targetRequest(for: words, leadingRules: leadingRules)
    } catch Failure.noRoom {
      targets.requiresRunFreeTargets = false
      _ = try targets.targetRequest(for: words, leadingRules: leadingRules)
      throw Failure.unsettled(words: words, columns: columns, rows: maxRows ?? rows)
    }
    return request
  }

  package func finishPreparation(
    _ request: BoardRequest, observing: ((Duration, Duration) -> Void)? = nil
  ) throws -> BoardRequest {
    for seed in UInt64(0)..<UInt64(Generation.settings.fill.seeds) {
      let start = observing.map { _ in ContinuousClock.now }
      let targets = request.targets(seed: seed)
      let repacking = start?.duration(to: .now)
      let fillStart = observing.map { _ in ContinuousClock.now }
      let fallback = RunFreeFill(
        board: targets, weights: weights, rules: rules,
        conditionalCharacters: conditionalCharacters
      ).filled(seed: seed)
      if let repacking, let fillStart {
        observing?(repacking, fillStart.duration(to: .now))
      }
      if let fallback {
        return request.avoidingRuns(
          fallback: fallback, weights: weights, symbols: conditionalCharacters)
      }
    }
    throw Failure.unsettled(words: request.words, columns: columns, rows: maxRows ?? rows)
  }

  private func targetRequest(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let symbols = conditionalCharacters.union(words.joined().filter { !$0.isLetter })
    var generator = self
    if !symbols.isEmpty {
      guard let ordinary = weights.letters(excluding: symbols) else {
        throw Failure.noRoom(words: words, columns: columns, rows: rows)
      }
      generator.weights = ordinary
    }
    return try generator.packedRequest(
      for: words, leadingRules: leadingRules,
      maxRows: maxRows ?? rows + words.map(\.count).reduce(0, +))
  }

  private func validateConfiguration() throws {
    guard columns > 0, rows > 0, !directions.isEmpty, downWords.lowerBound >= 0,
      rules.allSatisfy(\.isValid), maxRows.map({ $0 >= rows }) ?? true, hasValidDirectionLimit
    else { throw Failure.invalidConfiguration }
  }

  func targets(for request: BoardRequest, seed: UInt64) -> Board {
    Board(targets: packedLayout(for: request, seed: seed), columns: columns)
  }
}
