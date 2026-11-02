struct WordIndex: Sendable {
  private struct Node: Sendable {
    var letters: [Int] = []
    var children: [Int] = []
    var word: String?
    var wordCount = 0

    func child(for letter: Int) -> Int? {
      letters.firstIndex(of: letter).map { children[$0] }
    }
  }

  private var nodes = [Node()]
  private var alphabet: [Character: Int] = [:]
  private(set) var longest = 0

  init(_ words: Set<String>) {
    for word in words {
      if !word.isEmpty { nodes[0].wordCount += 1 }
      longest = max(longest, word.count)
      var index = 0
      for character in word {
        let letter = code(adding: character)
        if let next = nodes[index].child(for: letter) {
          index = next
        } else {
          let next = nodes.count
          nodes.append(Node())
          nodes[index].letters.append(letter)
          nodes[index].children.append(next)
          index = next
        }
        nodes[index].wordCount += 1
      }
      nodes[index].word = word
    }
  }

  private mutating func code(adding character: Character) -> Int {
    if let code = alphabet[character] { return code }
    let code = alphabet.count
    alphabet[character] = code
    return code
  }

  func code(of letter: Character) -> Int? { alphabet[letter] }

  func next(after index: Int?, code: Int) -> Int? {
    index.flatMap { nodes[$0].child(for: code) }
  }

  func next(after index: Int?, letter: Character) -> Int? {
    code(of: letter).flatMap { next(after: index, code: $0) }
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
