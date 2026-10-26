struct WordIndex: Sendable {
  private struct Node: Sendable {
    var children: [Character: Int] = [:]
    var word: String?
    var wordCount = 0
  }

  private var nodes = [Node()]
  private(set) var longest = 0

  init(_ words: Set<String>) {
    for word in words {
      if !word.isEmpty { nodes[0].wordCount += 1 }
      longest = max(longest, word.count)
      var index = 0
      for letter in word {
        if let next = nodes[index].children[letter] {
          index = next
        } else {
          let next = nodes.count
          nodes.append(Node())
          nodes[index].children[letter] = next
          index = next
        }
        nodes[index].wordCount += 1
      }
      nodes[index].word = word
    }
  }

  func next(after index: Int?, letter: Character) -> Int? {
    index.flatMap { nodes[$0].children[letter] }
  }

  func word(at index: Int?) -> String? {
    index.flatMap { nodes[$0].word }
  }

  func wordCount(below index: Int) -> Int { nodes[index].wordCount }

  func path(to word: String) -> [Int] {
    var path = [0]
    for letter in word {
      guard let next = next(after: path.last, letter: letter) else { return [] }
      path.append(next)
    }
    return path
  }
}
