extension BoardGenerator {
  public func accepts(_ words: [String], firstRule: WordRule? = nil) -> Bool {
    let words = words.map(\.cellUppercased)
    let excluded = conditionalCharacters.union(words.joined().filter { !$0.isLetter })
    guard !words.isEmpty, Set(words).count == words.count, words.allSatisfy({ $0.count > 1 }),
      !words.contains(where: { word in words.contains { $0 != word && $0.contains(word) } }),
      filler.letters(excluding: excluded) != nil
    else { return false }
    let fitting = words.indices.map { index in
      (index == 0 ? firstRule.map { [$0] } ?? rules : rules).flatMap { rule in
        rule.startDirections.map { WordRule(startDirections: [$0], turns: rule.turns) }
      }.filter { $0.canFit(length: words[index].count, columns: columns, maximumRows: maxRows) }
    }
    guard fitting.allSatisfy({ !$0.isEmpty }) else { return false }
    let mustStand = fitting.filter { $0.allSatisfy { $0.startDirections[0].isVertical } }.count
    let canStand = fitting.filter { $0.contains { $0.startDirections[0].isVertical } }.count
    return mustStand <= downWords.upperBound && canStand >= downWords.lowerBound
  }

  func packedRequest(
    for words: [String], firstDirection: Direction?, firstRule: WordRule?, maxRows: Int
  ) throws -> BoardRequest {
    guard accepts(words, firstRule: firstRule) else {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    if self.maxRows == nil {
      return try growingRequest(
        for: words, firstDirection: firstDirection, firstRule: firstRule, tallest: maxRows)
    }
    var unsettled = false
    for height in rows...maxRows {
      switch packing(height: height, firstRule: firstRule, words: words).pack(words) {
      case .placed(let placements):
        return BoardRequest(
          words: words, firstDirection: firstDirection, generator: self, firstRule: firstRule,
          layout: Layout(rows: height, placements: placements))
      case .impossible:
        continue
      case .undetermined:
        unsettled = true
      }
    }
    if unsettled { throw Failure.unsettled(words: words, columns: columns, rows: maxRows) }
    throw Failure.noRoom(words: words, columns: columns, rows: rows)
  }

  private func growingRequest(
    for words: [String], firstDirection: Direction?, firstRule: WordRule?, tallest: Int
  ) throws -> BoardRequest {
    func outcome(at height: Int) -> PathPacking.Outcome {
      packing(height: height, firstRule: firstRule, words: words).pack(words)
    }
    func placed(at height: Int) -> [Placement]? {
      guard case .placed(let placements) = outcome(at: height) else { return nil }
      return placements
    }
    if let placements = placed(at: rows) {
      return BoardRequest(
        words: words, firstDirection: firstDirection, generator: self, firstRule: firstRule,
        layout: Layout(rows: rows, placements: placements))
    }
    var found: (height: Int, placements: [Placement])
    switch outcome(at: tallest) {
    case .placed(let placements):
      found = (tallest, placements)
    case .impossible:
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    case .undetermined:
      throw Failure.unsettled(words: words, columns: columns, rows: tallest)
    }
    var lowest = rows + 1
    while lowest < found.height {
      let middle = (lowest + found.height) / 2
      if let placements = placed(at: middle) {
        found = (middle, placements)
      } else {
        lowest = middle + 1
      }
    }
    return BoardRequest(
      words: words, firstDirection: firstDirection, generator: self, firstRule: firstRule,
      layout: Layout(rows: found.height, placements: found.placements))
  }

  func packedLayout(for request: BoardRequest, seed: UInt64) -> Layout {
    let layout = request.layout
    let outcome = packing(height: layout.rows, firstRule: request.firstRule, words: request.words)
      .pack(request.words, seed: seed)
    guard case .placed(let placements) = outcome else { return layout }
    return Layout(rows: layout.rows, placements: placements)
  }

  private func requiredSymbols(in words: [String]) -> Set<Character> {
    let used = Set(words.joined())
    return conditionalCharacters.union(used.filter { !$0.isLetter }).intersection(used)
  }

  static let growingHeightNodeLimit = Generation.settings.packing.growingHeightNodeLimit

  private func packing(height: Int, firstRule: WordRule?, words: [String]) -> PathPacking {
    var packing = PathPacking(
      columns: columns, rows: height, rules: rules, firstRule: firstRule, downWords: downWords)
    if maxRows == nil { packing.nodeLimit = Self.growingHeightNodeLimit }
    let required = requiredSymbols(in: words)
    let (columns, rules, avoidsRuns) = (columns, rules, requiresRunFreeTargets)
    packing.completes = { placements, budget in
      let layout = Layout(rows: height, placements: placements)
      guard !avoidsRuns || !layout.hasForbiddenTargetRun(columns: columns) else {
        return .doesNotFit
      }
      guard let needing = layout.charactersToCopyIfRoom(columns: columns) else {
        return .doesNotFit
      }
      return ConditionalFill.roomForDecoys(
        required.intersection(needing), beside: layout, columns: columns,
        rules: rules, budget: &budget)
    }
    return packing
  }
}
