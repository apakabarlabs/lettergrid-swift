struct PlacementCompatibility {
  let columns: Int
  let rows: Int
  let rules: [WordRule]
  let words: [String]
  let blank: Character

  func accepts(_ chosen: [Placement?]) -> Bool {
    let placements = chosen.compactMap { $0 }
    var letters = Array(repeating: Array(repeating: blank, count: columns), count: rows)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let areas = placements.map { Set($0.cells) }
    let nested = areas.indices.contains { inner in
      areas.indices.contains { $0 != inner && areas[inner].isSubset(of: areas[$0]) }
    }
    guard !nested else { return false }
    let board = Board(letters: letters, placements: placements)
    let counts = letterCounts(letters)
    guard
      placements.allSatisfy({
        standsAlone($0.word, among: counts) || board.hasSingleOccurrence(of: $0.word, rules: rules)
      })
    else { return false }
    return zip(chosen, words).allSatisfy { placement, word in
      placement != nil || !spells(word, from: counts)
        || leavesRoom(for: word, on: board, beside: areas)
    }
  }

  private func letterCounts(_ letters: [[Character]]) -> [Character: Int] {
    var counts: [Character: Int] = [:]
    for row in letters {
      for letter in row where letter != blank { counts[letter, default: 0] += 1 }
    }
    return counts
  }

  private func spells(_ word: String, from counts: [Character: Int]) -> Bool {
    var needed: [Character: Int] = [:]
    for letter in word { needed[letter, default: 0] += 1 }
    return needed.allSatisfy { counts[$0.key, default: 0] >= $0.value }
  }

  private func standsAlone(_ word: String, among counts: [Character: Int]) -> Bool {
    Set(word).count == word.count && word.allSatisfy { counts[$0] == 1 }
  }

  private func leavesRoom(for word: String, on board: Board, beside areas: [Set<Cell>]) -> Bool {
    var paths: Set<[Cell]> = []
    for reading in PathSearch(board: board, rules: rules, maximumReadings: 3)
      .readings(in: WordIndex([word]))
    where !paths.contains(Array(reading.cells.reversed())) {
      paths.insert(reading.cells)
    }
    guard let path = paths.first else { return true }
    return paths.count == 1 && !areas.contains { Set(path).isSubset(of: $0) }
  }
}
