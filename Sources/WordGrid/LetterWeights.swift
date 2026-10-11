public struct LetterWeights: Equatable, Sendable {
  public enum Failure: Error, Equatable {
    case empty
    case notALetter(String)
    case notPositive(String)
  }

  private let letters: [Character]
  private let thresholds: [Double]

  public init(_ weights: [String: Double]) throws {
    guard !weights.isEmpty else { throw Failure.empty }
    var letters: [Character] = []
    var thresholds: [Double] = []
    var total = 0.0
    for (key, weight) in weights.sorted(by: { $0.key < $1.key }) {
      guard key.count == 1, let letter = key.uppercased().first, letter.isLetter else {
        throw Failure.notALetter(key)
      }
      guard weight > 0 else { throw Failure.notPositive(key) }
      total += weight
      letters.append(letter)
      thresholds.append(total)
    }
    self.letters = letters
    self.thresholds = thresholds
  }

  func letter(using random: inout SeededRandom) -> Character {
    let point = Double.random(in: 0..<(thresholds.last ?? 1), using: &random)
    let index = thresholds.firstIndex { point < $0 } ?? letters.count - 1
    return letters[index]
  }
}
