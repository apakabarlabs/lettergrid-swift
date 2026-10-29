public struct LetterWeights: Equatable, Sendable {
  private struct Candidate {
    let letter: Character
    var weight: Double
    let wide: WideNumber
  }

  private struct WideNumber {
    var significand: Double
    var exponent: Int

    init(_ value: Double) {
      significand = value.significand
      exponent = Int(value.exponent)
    }

    func times(_ factor: Double, count: Int) -> WideNumber {
      var result = self
      for _ in 0..<count {
        let product = result.significand * factor
        result.significand = product.significand
        result.exponent += Int(product.exponent)
      }
      return result
    }

    func scaled(below exponent: Int) -> Double {
      Double(sign: .plus, exponent: self.exponent - exponent, significand: significand)
    }
  }

  public enum Failure: Error, Equatable {
    case empty
    case notALetter(String)
    case notPositive(String)
    case notFinite(String)
    case sameNeighbourOutsideFraction(Double)
  }

  private let letters: [Character]
  private let weights: [Double]
  public let sameNeighbour: Double

  var letterCount: Int { letters.count }

  public init(_ weights: [String: Double], sameNeighbour: Double = 1) throws {
    guard !weights.isEmpty else { throw Failure.empty }
    guard sameNeighbour > 0, sameNeighbour <= 1 else {
      throw Failure.sameNeighbourOutsideFraction(sameNeighbour)
    }
    var letters: [Character] = []
    var orderedWeights: [Double] = []
    for (key, weight) in weights.sorted(by: { $0.key < $1.key }) {
      guard key.count == 1, let letter = key.first?.cellUppercased, letter.isLetter else {
        throw Failure.notALetter(key)
      }
      guard weight.isFinite else { throw Failure.notFinite(key) }
      guard weight > 0 else { throw Failure.notPositive(key) }
      if let index = letters.firstIndex(of: letter) {
        orderedWeights[index] += weight
        guard orderedWeights[index].isFinite else { throw Failure.notFinite(key) }
      } else {
        letters.append(letter)
        orderedWeights.append(weight)
      }
    }
    self.letters = letters
    self.weights = orderedWeights
    self.sameNeighbour = sameNeighbour
  }

  private init(letters: [Character], weights: [Double], sameNeighbour: Double) {
    self.letters = letters
    self.weights = weights
    self.sameNeighbour = sameNeighbour
  }

  func letters(excluding used: Set<Character>) -> LetterWeights? {
    let kept = zip(letters, weights).filter { !used.contains($0.0) }
    guard !kept.isEmpty else { return nil }
    return LetterWeights(
      letters: kept.map(\.0), weights: kept.map(\.1), sameNeighbour: sameNeighbour)
  }

  func orderedLetters(
    using random: inout SeededRandom, neighbours: [Character: Int] = [:]
  ) -> [Character] {
    var remaining = candidates(neighbours: neighbours)
    var ordered: [Character] = []
    while !remaining.isEmpty {
      let chosen = draw(from: &remaining, using: &random)
      ordered.append(chosen)
      remaining.removeAll { $0.letter == chosen }
    }
    return ordered
  }

  private func candidates(neighbours: [Character: Int]) -> [Candidate] {
    zip(letters, weights).map { letter, weight in
      let count = neighbours[letter] ?? 0
      var product = weight
      for _ in 0..<count { product *= sameNeighbour }
      return Candidate(
        letter: letter, weight: product,
        wide: WideNumber(weight).times(sameNeighbour, count: count))
    }
  }

  private func draw(
    from candidates: inout [Candidate], using random: inout SeededRandom
  ) -> Character {
    var total = candidates.reduce(0) { $0 + $1.weight }
    if !total.isFinite || total == 0 {
      let largest = candidates.map(\.wide.exponent).max() ?? 0
      for index in candidates.indices {
        candidates[index].weight = candidates[index].wide.scaled(below: largest)
      }
      total = candidates.reduce(0) { $0 + $1.weight }
    }
    var point = random.nextDouble(below: total)
    for candidate in candidates {
      point -= candidate.weight
      if point < 0 { return candidate.letter }
    }
    return candidates[candidates.count - 1].letter
  }
}
