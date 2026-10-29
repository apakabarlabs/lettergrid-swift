import Foundation

extension Character {
  public var cellUppercased: Character {
    let composed = String(self).precomposedStringWithCanonicalMapping
    let upper = composed.uppercased().precomposedStringWithCanonicalMapping
    return Character(upper.count == 1 ? upper : composed)
  }

  func precedesInCodePoints(_ other: Character) -> Bool {
    String(self).precedesInCodePoints(String(other))
  }
}

extension String {
  public var cellUppercased: String { String(map(\.cellUppercased)) }

  func precedesInCodePoints(_ other: String) -> Bool {
    unicodeScalars.lexicographicallyPrecedes(other.unicodeScalars) { $0.value < $1.value }
  }
}
