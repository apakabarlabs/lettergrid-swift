public struct BoardGenerationLimits: Equatable, Sendable {
  public static let standard = Self(attempts: 200, fillsPerAttempt: 20, layoutsPerAttempt: 40)
  public let attempts: Int
  public let fillsPerAttempt: Int
  public let layoutsPerAttempt: Int

  public init(attempts: Int, fillsPerAttempt: Int, layoutsPerAttempt: Int) {
    self.attempts = attempts
    self.fillsPerAttempt = fillsPerAttempt
    self.layoutsPerAttempt = layoutsPerAttempt
  }
}

struct PathBoardBuilder {
  let columns: Int
  let minimumRows: Int
  let rules: [WordRule]
  var downWords: ClosedRange<Int> = 0...Int.max
  var generationVersion: BoardGenerationVersion = .current
  var maximumRows: Int?
  var avoidsTargetRuns = false

  func preparedLayout(
    for words: [String], firstRule: WordRule?, filler: LetterWeights,
    tries: Int = BoardGenerationLimits.standard.layoutsPerAttempt
  ) -> Layout? {
    guard !words.isEmpty, Set(words).count == words.count,
      words.allSatisfy({ $0.count > 1 }),
      !words.contains(where: { word in words.contains { $0 != word && $0.contains(word) } }),
      let free = filler.letters(excluding: Set(words.joined()))
    else { return nil }
    var random = SeededRandom(seed: requestSeed(for: words))
    guard maximumRows != nil else {
      return isolatedLayout(for: words, firstRule: firstRule, filler: free, using: &random)
    }
    for _ in 0..<max(1, tries) {
      guard
        let isolated = isolatedLayout(
          for: words, firstRule: firstRule, filler: free, using: &random),
        let compact = compacted(isolated, using: &random)
      else { continue }
      if targetsAreUnique(filled(compact, with: free, using: &random)) { return compact }
    }
    return nil
  }

  private func isolatedLayout(
    for words: [String], firstRule: WordRule?, filler free: LetterWeights,
    using random: inout SeededRandom
  ) -> Layout? {
    let choices = words.enumerated().map { index, word in
      candidates(
        for: word, rules: index == 0 ? firstRule.map { [$0] } ?? rules : rules,
        filler: free, using: &random)
    }
    guard choices.allSatisfy({ !$0.isEmpty }) else { return nil }
    let forced = choices.indices.filter { choices[$0].allSatisfy { $0.direction.isVertical } }
    let optional = choices.indices.filter { index in
      !forced.contains(index) && choices[index].contains { $0.direction.isVertical }
    }
    let minimum = max(forced.count, downWords.lowerBound)
    let maximum = min(downWords.upperBound, forced.count + optional.count)
    guard minimum <= maximum else { return nil }
    let vertical = Set(forced + optional.prefix(minimum - forced.count))
    var placements: [Placement] = []
    var nextRow = 0
    for index in words.indices {
      guard
        let chosen = choices[index].filter({ $0.direction.isVertical == vertical.contains(index) })
          .randomElement(using: &random)
      else { return nil }
      let moved = chosen.cells.map { Cell(row: $0.row + nextRow, column: $0.column) }
      placements.append(Placement(word: words[index], cells: moved))
      nextRow = (moved.map(\.row).max() ?? nextRow) + 2
    }
    let layout = Layout(rows: max(minimumRows, nextRow - 1), placements: placements)
    let board = filled(layout, with: free, using: &random)
    return targetsAreUnique(board) ? layout : nil
  }

  private func requestSeed(for words: [String]) -> UInt64 {
    let ruleNames = rules.map {
      $0.startDirections.map(\.rawValue).joined(separator: ",") + ":\($0.turns)"
    }
    let text = words.joined(separator: "\0") + "\0" + ruleNames.joined(separator: "\0")
    return text.unicodeScalars.reduce(UInt64(0xCBF2_9CE4_8422_2325)) {
      ($0 ^ UInt64($1.value)) &* 0x100_0000_01B3
    }
  }

  func board(
    layout: Layout, filler: LetterWeights, dictionary: WordIndex, seed: UInt64,
    limits: BoardGenerationLimits, fixed: [Cell: Character] = [:]
  ) -> Board {
    var random = SeededRandom(seed: seed)
    var best: Board?
    var leastNoise = Int.max
    for _ in 0..<limits.attempts {
      let compact =
        generationVersion == .v0p18 && maximumRows != nil
        ? layout : lowestLayout(layout, tries: limits.layoutsPerAttempt, using: &random)
      for _ in 0..<limits.fillsPerAttempt {
        let board = filled(compact, with: filler, fixed: fixed, using: &random)
        guard targetsAreUnique(board) else { continue }
        if generationVersion == .v0p12 {
          if !board.hasStrayWord(in: dictionary, rules: rules) { return board }
        } else {
          let noise = board.strayWordCount(in: dictionary, rules: rules, lessThan: leastNoise)
          if noise == 0 { return board }
          if best == nil || noise < leastNoise {
            best = board
            leastNoise = noise
          }
        }
      }
    }
    if let best { return best }
    guard let free = filler.letters(excluding: Set(layout.placements.map(\.word).joined())) else {
      preconditionFailure("A prepared path layout requires unused filler letters")
    }
    return filled(layout, with: free, fixed: fixed, using: &random)
  }

  private func candidates(
    for word: String, rules chosenRules: [WordRule], filler: LetterWeights,
    using random: inout SeededRandom
  ) -> [Placement] {
    let categories = Set(chosenRules.flatMap(\.startDirections).map(\.isVertical))
    var found: [Placement] = []
    for rule in chosenRules.shuffled(using: &random) {
      for direction in rule.startDirections.shuffled(using: &random) {
        if found.contains(where: { $0.direction.isVertical == direction.isVertical }) { continue }
        let directed = WordRule(startDirections: [direction], turns: rule.turns)
        if let placement = candidate(for: word, rule: directed, filler: filler, using: &random) {
          found.append(placement)
        }
      }
      if found.count == categories.count { break }
    }
    return found
  }

  private func candidate(
    for word: String, rule: WordRule, filler: LetterWeights, using random: inout SeededRandom
  ) -> Placement? {
    let seed = random.next()
    for limit in [1, 256] {
      for cells in PathShapes(
        columns: columns, length: word.count, rule: rule,
        maximumShapes: limit, maximumRows: maximumRows
      ).cells(seed: seed) {
        let placement = Placement(word: word, cells: cells)
        let layout = Layout(rows: (cells.map(\.row).max() ?? 0) + 1, placements: [placement])
        if avoidsTargetRuns, layout.hasForbiddenTargetRun(columns: columns) { continue }
        let board = filled(layout, with: filler, using: &random)
        if Set(word).count == word.count || board.hasSingleOccurrence(of: word, rules: rules) {
          return placement
        }
      }
    }
    return nil
  }

  private func targetsAreUnique(_ board: Board) -> Bool {
    let layout = Layout(rows: board.rows, placements: board.placements)
    return (!avoidsTargetRuns || !layout.hasForbiddenTargetRun(columns: columns))
      && board.placements.allSatisfy { board.hasSingleOccurrence(of: $0.word, rules: rules) }
  }

  private func lowestLayout(
    _ fallback: Layout, tries: Int, using random: inout SeededRandom
  ) -> Layout {
    var best: Layout?
    for _ in 0..<max(1, tries) {
      guard let candidate = compacted(fallback, using: &random) else { continue }
      if avoidsTargetRuns, candidate.hasForbiddenTargetRun(columns: columns) { continue }
      if best.map({
        candidate.rows < $0.rows
          || (candidate.rows == $0.rows && candidate.sharedCells > $0.sharedCells)
      }) ?? true {
        best = candidate
      }
    }
    return best ?? fallback
  }

  private func compacted(_ layout: Layout, using random: inout SeededRandom) -> Layout? {
    var placed: [Int: Placement] = [:]
    var occupied: [Cell: Character] = [:]
    var rows = minimumRows
    for index in layout.placements.indices.sorted(by: {
      layout.placements[$0].word.count > layout.placements[$1].word.count
    }) {
      let placement = layout.placements[index]
      let top = placement.cells.map(\.row).min() ?? 0
      let height = (placement.cells.map(\.row).max() ?? 0) - top + 1
      rows = max(rows, height)
      guard maximumRows.map({ rows <= $0 }) ?? true else { return nil }
      var candidates: [Placement] = []
      while candidates.isEmpty {
        candidates = fittingTranslations(of: placement, rows: rows, beside: occupied)
        if candidates.isEmpty {
          if let maximumRows, rows >= maximumRows { return nil }
          rows += 1
        }
      }
      let shared = candidates.map { $0.cells.filter { occupied[$0] != nil }.count }.max() ?? 0
      guard
        let chosen = candidates.filter({
          $0.cells.filter { occupied[$0] != nil }.count == shared
        }).randomElement(using: &random)
      else {
        preconditionFailure("A path always fits after growing the board")
      }
      placed[index] = chosen
      for (cell, letter) in zip(chosen.cells, chosen.word) { occupied[cell] = letter }
    }
    let ordered = layout.placements.indices.map { index in
      guard let placement = placed[index] else { preconditionFailure("Every word was placed") }
      return placement
    }
    return Layout(
      rows: max(minimumRows, (ordered.flatMap(\.cells).map(\.row).max() ?? 0) + 1),
      placements: ordered)
  }

  private func fittingTranslations(
    of placement: Placement, rows: Int, beside occupied: [Cell: Character]
  ) -> [Placement] {
    let top = placement.cells.map(\.row).min() ?? 0
    let left = placement.cells.map(\.column).min() ?? 0
    let height = (placement.cells.map(\.row).max() ?? 0) - top + 1
    let width = (placement.cells.map(\.column).max() ?? 0) - left + 1
    var candidates: [Placement] = []
    for row in 0...(rows - height) {
      for column in 0...(columns - width) {
        let cells = placement.cells.map {
          Cell(row: $0.row - top + row, column: $0.column - left + column)
        }
        if zip(cells, placement.word).allSatisfy({ cell, letter in
          occupied[cell].map { $0 == letter } ?? true
        }) {
          candidates.append(Placement(word: placement.word, cells: cells))
        }
      }
    }
    return candidates
  }

}

extension PathBoardBuilder {
  private func filled(
    _ layout: Layout, with filler: LetterWeights, fixed: [Cell: Character] = [:],
    using random: inout SeededRandom
  ) -> Board {
    var letters = Array(repeating: [Character?](repeating: nil, count: columns), count: layout.rows)
    for (cell, letter) in fixed {
      letters[cell.row][cell.column] = letter
    }
    for placement in layout.placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let neighbours = LetterNeighbours(columns: columns, rows: layout.rows)
    for row in letters.indices {
      for column in 0..<columns where letters[row][column] == nil {
        let counts = neighbours.counts(around: Cell(row: row, column: column)) {
          letters[$0.row][$0.column]
        }
        letters[row][column] = filler.randomLetter(using: &random, neighbours: counts)
      }
    }
    return Board(
      letters: letters.map { line in
        line.map { letter in
          guard let letter else { preconditionFailure("Every path board cell has been filled") }
          return letter
        }
      }, placements: layout.placements)
  }
}
