struct PathPacking {
  enum Outcome: Equatable {
    case placed([Placement])
    case impossible
    case undetermined
  }

  enum Completion {
    case fits
    case doesNotFit
    case ranOut
  }

  private struct Candidate {
    let slots: [Int]
    let placement: Placement
  }

  private struct Search {
    let words: [[Character]]
    let choices: [[Candidate]]
    let order: [Int]
    let downWords: ClosedRange<Int>
    let nodeLimit: Int
    let standApart: ([Placement?]) -> Bool
    let completes: ([Placement], inout Int) -> Completion
    var letters: [Character?]
    var uses: [Int]
    var chosen: [Placement?]
    var vertical = 0
    var nodes = 0
    var exhausted = false

    var sharedCells: Int { uses.reduce(0) { $0 + max($1 - 1, 0) } }

    mutating func place(at depth: Int) -> Bool {
      guard depth < order.count else {
        guard downWords.contains(vertical) else { return false }
        var budget = nodeLimit - nodes
        let completion = completes(chosen.compactMap { $0 }, &budget)
        nodes = nodeLimit - budget
        switch completion {
        case .fits: return true
        case .doesNotFit: return false
        case .ranOut:
          exhausted = true
          return false
        }
      }
      let index = order[depth]
      let remaining = order.count - depth - 1
      for candidate in crossingFirst(choices[index], word: words[index]) {
        nodes += 1
        guard nodes <= nodeLimit else {
          exhausted = true
          return false
        }
        let counted = vertical + (candidate.placement.direction.isVertical ? 1 : 0)
        guard counted <= downWords.upperBound, counted + remaining >= downWords.lowerBound,
          fits(candidate, word: words[index])
        else { continue }
        apply(candidate, word: words[index])
        chosen[index] = candidate.placement
        vertical = counted
        if standApart(chosen), place(at: depth + 1) { return true }
        vertical -= candidate.placement.direction.isVertical ? 1 : 0
        chosen[index] = nil
        remove(candidate)
        if exhausted { return false }
      }
      return false
    }

    private func crossingFirst(_ candidates: [Candidate], word: [Character]) -> [Candidate] {
      let shared = candidates.map { candidate in
        zip(candidate.slots, word).reduce(0) { $0 + (letters[$1.0] == $1.1 ? 1 : 0) }
      }
      guard shared.contains(where: { $0 > 0 }) else { return candidates }
      return candidates.indices.sorted {
        shared[$0] > shared[$1] || (shared[$0] == shared[$1] && $0 < $1)
      }
      .map { candidates[$0] }
    }

    private func fits(_ candidate: Candidate, word: [Character]) -> Bool {
      zip(candidate.slots, word).allSatisfy { slot, letter in
        letters[slot].map { $0 == letter } ?? true
      }
    }

    private mutating func apply(_ candidate: Candidate, word: [Character]) {
      for (slot, letter) in zip(candidate.slots, word) {
        letters[slot] = letter
        uses[slot] += 1
      }
    }

    private mutating func remove(_ candidate: Candidate) {
      for slot in candidate.slots {
        uses[slot] -= 1
        if uses[slot] == 0 { letters[slot] = nil }
      }
    }
  }

  let columns: Int
  let rows: Int
  let rules: [WordRule]
  var firstRule: WordRule?
  var downWords: ClosedRange<Int> = 0...Int.max
  var nodeLimit = 2_000_000
  var crossingRestarts = 8
  var completes: @Sendable ([Placement], inout Int) -> Completion = { _, _ in .fits }

  func pack(_ words: [String], seed: UInt64 = 0) -> Outcome {
    precondition(
      firstRule.map { first in
        rules.contains {
          $0.turns == first.turns && Set(first.startDirections).isSubset(of: $0.startDirections)
        }
      } ?? true,
      "The first word's rule must lie within one of the rules every reading is checked against.")
    var random = SeededRandom(seed: seed)
    let used = Set(words.joined())
    guard !words.isEmpty,
      let blank = (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
        .first(where: { !used.contains($0) })
    else { return .impossible }
    let compatibility = PlacementCompatibility(
      columns: columns, rows: rows, rules: rules, words: words, blank: blank)
    let all = standingAlone(words, compatibility: compatibility)
    guard all.allSatisfy({ !$0.isEmpty }) else { return .impossible }
    let canCross = words.indices.contains { first in
      words.indices.contains { $0 > first && !Set(words[first]).isDisjoint(with: words[$0]) }
    }
    var best: (placements: [Placement], shared: Int)?
    var spent = 0
    for _ in 0..<max(1, crossingRestarts) {
      let choices = all.map { random.shuffled($0) }
      var search = Search(
        words: words.map(Array.init), choices: choices,
        order: words.indices.sorted { choices[$0].count < choices[$1].count },
        downWords: downWords, nodeLimit: nodeLimit - spent,
        standApart: compatibility.accepts, completes: completes,
        letters: Array(repeating: nil, count: rows * columns),
        uses: Array(repeating: 0, count: rows * columns),
        chosen: Array(repeating: nil, count: words.count))
      guard search.place(at: 0) else {
        if let best { return .placed(best.placements) }
        return search.exhausted ? .undetermined : .impossible
      }
      spent += search.nodes
      let shared = search.sharedCells
      if best.map({ shared > $0.shared }) ?? true {
        best = (search.chosen.compactMap { $0 }, shared)
      }
      if shared > 0 || !canCross { break }
    }
    guard let best else { return .impossible }
    return .placed(best.placements)
  }

  private func standingAlone(
    _ words: [String], compatibility: PlacementCompatibility
  ) -> [[Candidate]] {
    let alone = [Placement?](repeating: nil, count: words.count)
    return words.indices.map { index in
      let allowedRules = index == 0 ? firstRule.map { [$0] } ?? rules : rules
      return candidates(for: words[index], rules: allowedRules) { placement in
        var chosen = alone
        chosen[index] = placement
        return compatibility.accepts(chosen)
      }
    }
  }

  private func candidates(
    for word: String, rules: [WordRule], accepting: (Placement) -> Bool
  ) -> [Candidate] {
    var seen: Set<[Cell]> = []
    var found: [Candidate] = []
    for rule in rules {
      for direction in rule.startDirections {
        let shapes = PathShapes(
          columns: columns, length: word.count,
          rule: WordRule(startDirections: [direction], turns: rule.turns),
          maximumShapes: Int.max, maximumRows: rows, visitedLimit: nil, randomized: false
        ).cells()
        for shape in shapes {
          let height = (shape.map(\.row).max() ?? 0) + 1
          let width = (shape.map(\.column).max() ?? 0) + 1
          guard height <= rows, width <= columns else { continue }
          guard accepting(Placement(word: word, cells: shape)) else { continue }
          for row in 0...(rows - height) {
            for column in 0...(columns - width) {
              let cells = shape.map { Cell(row: $0.row + row, column: $0.column + column) }
              guard seen.insert(cells).inserted else { continue }
              found.append(
                Candidate(
                  slots: cells.map { $0.row * columns + $0.column },
                  placement: Placement(word: word, cells: cells)))
            }
          }
        }
      }
    }
    return found
  }
}
