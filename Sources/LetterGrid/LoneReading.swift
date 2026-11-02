extension Placement {
  func readsOnceAlone(rules: [WordRule]) -> Bool {
    var search = LoneReading(cells: cells, letters: Array(word), target: Array(word), rules: rules)
    for start in cells.indices where search.letters[start] == search.target[0] {
      search.walk(from: start)
      if !search.single { return false }
    }
    return search.first != nil
  }

  func holdsReading(of word: String, rules: [WordRule]) -> Bool {
    var search = LoneReading(
      cells: cells, letters: Array(self.word), target: Array(word), rules: rules,
      stopsAtFirst: true)
    for start in cells.indices where search.letters[start] == search.target[0] {
      search.walk(from: start)
      if search.first != nil { return true }
    }
    return false
  }
}

private struct LoneReading {
  let cells: [Cell]
  let letters: [Character]
  let target: [Character]
  let rules: [WordRule]
  let palindrome: Bool
  let stopsAtFirst: Bool
  var path: [Int] = []
  var used: [Bool]
  var first: [Cell]?
  var single = true

  init(
    cells: [Cell], letters: [Character], target: [Character], rules: [WordRule],
    stopsAtFirst: Bool = false
  ) {
    self.cells = cells
    self.letters = letters
    self.target = target
    self.rules = rules
    self.stopsAtFirst = stopsAtFirst
    palindrome = target == target.reversed()
    used = Array(repeating: false, count: cells.count)
  }

  private var searching: Bool { single && !(stopsAtFirst && first != nil) }

  mutating func walk(from index: Int) {
    path.append(index)
    used[index] = true
    defer {
      path.removeLast()
      used[index] = false
    }
    guard path.count < target.count else {
      read(path.map { cells[$0] })
      return
    }
    let letter = target[path.count]
    for next in cells.indices where searching && !used[next] && letters[next] == letter {
      guard Direction.between(cells[index], cells[next]) != nil else { continue }
      walk(from: next)
    }
  }

  private mutating func read(_ reading: [Cell]) {
    guard let geometry = PathGeometry(reading), rules.contains(where: { $0.matches(geometry) })
    else { return }
    guard let first else {
      self.first = reading
      return
    }
    single = reading == first || (palindrome && reading == first.reversed())
  }
}
