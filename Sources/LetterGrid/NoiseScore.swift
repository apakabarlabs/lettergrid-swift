enum NoiseSearch {
  static let maximumVisits = 100_000
}

extension Board {
  func strayWordCount(
    in dictionary: WordIndex, rules: [WordRule], lessThan limit: Int = Int.max,
    maximumVisits: Int = NoiseSearch.maximumVisits, letters: ((Cell) -> Character?)? = nil
  ) -> Int {
    var words: Set<String> = []
    var removed: [Int: Int] = [:]
    var visits = 0
    var exhausted = false
    let skip: (Int) -> Bool = { node in
      guard visits < maximumVisits else {
        exhausted = true
        return true
      }
      visits += 1
      return removed[node, default: 0] >= dictionary.wordCount(below: node)
    }
    PathSearch(board: self, rules: rules, letters: letters).visitReadings(
      in: dictionary, skipping: skip
    ) { reading in
      guard !covers(reading) else { return true }
      if words.insert(reading.word).inserted {
        for node in dictionary.path(to: reading.word) { removed[node, default: 0] += 1 }
      }
      return words.count < limit
    }
    return exhausted ? Int.max : words.count
  }
}
