struct WordIndex: Sendable {
  private struct Node: Sendable {
    var children: [Character: Int] = [:]
    var word: String?
  }

  private var nodes = [Node()]
  private(set) var longest = 0

  init(_ words: Set<String>) {
    for word in words {
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
}
