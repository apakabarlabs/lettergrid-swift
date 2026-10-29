extension BoardGenerator {
  public func accepts(_ words: [String], firstRule: WordRule? = nil) -> Bool {
    let words = words.map(\.cellUppercased)
    let excluded = Set(words.joined()).union(conditionalCharacters)
    guard !words.isEmpty, Set(words).count == words.count, words.allSatisfy({ $0.count > 1 }),
      !words.contains(where: { word in words.contains { $0 != word && $0.contains(word) } }),
      filler.letters(excluding: excluded) != nil
    else { return false }
    return words.indices.allSatisfy { index in
      (index == 0 ? firstRule.map { [$0] } ?? rules : rules).contains {
        $0.canFit(length: words[index].count, columns: columns, maximumRows: maxRows)
      }
    }
  }

  func packedRequest(
    for words: [String], firstRule: WordRule?, maxRows: Int
  ) throws -> BoardRequest {
    guard accepts(words, firstRule: firstRule) else {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    var unsettled = false
    for height in rows...maxRows {
      switch packing(height: height, firstRule: firstRule, words: words).pack(words) {
      case .placed(let placements):
        return BoardRequest(
          words: words, firstDirection: nil, generator: self, firstRule: firstRule,
          pathLayout: Layout(rows: height, placements: placements))
      case .impossible:
        continue
      case .undetermined:
        unsettled = true
      }
    }
    if unsettled { throw Failure.unsettled(words: words, columns: columns, rows: maxRows) }
    throw Failure.noRoom(words: words, columns: columns, rows: rows)
  }

  func packedLayout(for request: BoardRequest, seed: UInt64) -> Layout? {
    guard packs, let layout = request.pathLayout else {
      return request.pathLayout
    }
    let outcome = packing(height: layout.rows, firstRule: request.firstRule, words: request.words)
      .pack(request.words, seed: seed)
    guard case .placed(let placements) = outcome else { return layout }
    return Layout(rows: layout.rows, placements: placements)
  }

  var packs: Bool { usesPathRules && maxRows != nil }

  private func requiredSymbols(in words: [String]) -> Set<Character> {
    let used = Set(words.joined())
    return conditionalCharacters.union(used.filter { !$0.isLetter }).intersection(used)
  }

  private func packing(height: Int, firstRule: WordRule?, words: [String]) -> PathPacking {
    var packing = PathPacking(
      columns: columns, rows: height, rules: rules, firstRule: firstRule, downWords: downWords)
    let required = requiredSymbols(in: words)
    guard requiresRunFreeTargets || !required.isEmpty else { return packing }
    let (columns, rules, avoidsRuns) = (columns, rules, requiresRunFreeTargets)
    packing.completes = { placements in
      let layout = Layout(rows: height, placements: placements)
      guard !avoidsRuns || !layout.hasForbiddenTargetRun(columns: columns) else { return false }
      guard !required.isEmpty else { return true }
      return ConditionalFill.decoys(
        required, beside: layout, columns: columns,
        rules: rules, seed: 0) != nil
    }
    return packing
  }
}
