extension Placement {
  func readsOnceAlone(rules: [WordRule]) -> Bool {
    var search = LoneReading(cells: cells, letters: Array(word), rules: rules)
    for start in cells.indices where search.letters[start] == search.letters[0] {
      search.walk(from: start)
      if !search.single { return false }
    }
    return search.first != nil
  }
}

private struct LoneReading {
  let cells: [Cell]
  let letters: [Character]
  let rules: [WordRule]
  let palindrome: Bool
  var path: [Int] = []
  var used: [Bool]
  var first: [Cell]?
  var single = true

  init(cells: [Cell], letters: [Character], rules: [WordRule]) {
    self.cells = cells
    self.letters = letters
    self.rules = rules
    palindrome = letters == letters.reversed()
    used = Array(repeating: false, count: cells.count)
  }

  mutating func walk(from index: Int) {
    path.append(index)
    used[index] = true
    defer {
      path.removeLast()
      used[index] = false
    }
    guard path.count < letters.count else {
      read(path.map { cells[$0] })
      return
    }
    let letter = letters[path.count]
    for next in cells.indices where single && !used[next] && letters[next] == letter {
      guard Direction.between(cells[index], cells[next]) != nil else { continue }
      walk(from: next)
    }
  }

  private mutating func read(_ reading: [Cell]) {
    guard rules.contains(where: { $0.matches(reading) }) else { return }
    guard let first else {
      self.first = reading
      return
    }
    single = reading == first || (palindrome && reading == first.reversed())
  }
}
