import Foundation

public struct LetterWeights: Equatable, Sendable {
  public enum Failure: Error, Equatable {
    case empty
    case notALetter(String)
    case notPositive(String)
    case sameNeighbourOutsideFraction(Double)
  }

  private let letters: [Character]
  private let weights: [Double]
  public let sameNeighbour: Double

  var letterCount: Int { Set(letters).count }

  public init(_ weights: [String: Double], sameNeighbour: Double = 1) throws {
    guard !weights.isEmpty else { throw Failure.empty }
    guard sameNeighbour > 0, sameNeighbour <= 1 else {
      throw Failure.sameNeighbourOutsideFraction(sameNeighbour)
    }
    var letters: [Character] = []
    var orderedWeights: [Double] = []
    for (key, weight) in weights.sorted(by: { $0.key < $1.key }) {
      guard key.count == 1, let letter = key.uppercased().first, letter.isLetter else {
        throw Failure.notALetter(key)
      }
      guard weight > 0 else { throw Failure.notPositive(key) }
      letters.append(letter)
      orderedWeights.append(weight)
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
    var remaining = zip(letters, weights).map { letter, weight in
      (letter, weight * pow(sameNeighbour, Double(neighbours[letter] ?? 0)))
    }
    var ordered: [Character] = []
    while !remaining.isEmpty {
      let total = remaining.reduce(0) { $0 + $1.1 }
      var point = Double.random(in: 0..<total, using: &random)
      var chosen = remaining[remaining.count - 1].0
      for (letter, weight) in remaining {
        point -= weight
        if point < 0 {
          chosen = letter
          break
        }
      }
      ordered.append(chosen)
      remaining.removeAll { $0.0 == chosen }
    }
    return ordered
  }
}
