import Testing

@testable import LetterGrid

struct LetterWeightsTests {
  @Test(arguments: [Double.infinity, -.infinity, .nan])
  func nonFiniteWeightsAreRejected(_ weight: Double) {
    #expect(throws: LetterWeights.Failure.notFinite("a")) {
      try LetterWeights(["a": weight])
    }
  }

  @Test func keysEqualAfterUppercasingAreOneLetterWithTheirWeightsAdded() throws {
    let merged = try LetterWeights(["a": 1, "A": 2, "b": 3])
    #expect(merged.letterCount == 2)
    #expect(merged == (try LetterWeights(["a": 3, "b": 3])))
  }

  @Test func mergedKeysWhoseWeightsOverflowAreRejected() {
    #expect(throws: LetterWeights.Failure.notFinite("a")) {
      try LetterWeights(["A": .greatestFiniteMagnitude, "a": .greatestFiniteMagnitude])
    }
  }

  @Test func finiteWeightsWhoseSumOverflowsStillProduceEveryLetter() throws {
    let weights = try LetterWeights([
      "a": Double.greatestFiniteMagnitude, "b": Double.greatestFiniteMagnitude,
      "c": Double.leastNonzeroMagnitude,
    ])
    var random = SeededRandom(seed: 42)

    let ordered = weights.orderedLetters(using: &random)

    #expect(ordered.count == 3)
    #expect(Set(ordered) == Set("ABC"))
  }

  @Test func neighbourPenaltiesThatUnderflowStillProduceEveryLetter() throws {
    let weights = try LetterWeights(
      ["a": 1, "b": Double.leastNonzeroMagnitude],
      sameNeighbour: Double.leastNonzeroMagnitude)
    var random = SeededRandom(seed: 42)

    let ordered = weights.orderedLetters(using: &random, neighbours: ["A": 8, "B": 8])

    #expect(ordered.count == 2)
    #expect(Set(ordered) == Set("AB"))
    #expect(ordered.first == "A")
  }

  @Test(arguments: [
    (["\u{E9}": 1.0, "z": 1.0], ["e\u{301}": 1.0, "z": 1.0]),
    (["a": 1.0, "B": 2.0], ["A": 1.0, "b": 2.0]),
  ])
  func weightsThatNormaliseAlikeAreEqualAndDrawAlike(
    first: [String: Double], second: [String: Double]
  ) throws {
    let (left, right) = (try LetterWeights(first), try LetterWeights(second))
    var leftRandom = SeededRandom(seed: 3)
    var rightRandom = SeededRandom(seed: 3)

    #expect(left == right)
    #expect(left.orderedLetters(using: &leftRandom) == right.orderedLetters(using: &rightRandom))
  }

  @Test func anUnderflowingPenaltySharedByEveryLetterKeepsTheirWeightRatio() throws {
    let weights = try LetterWeights(
      ["a": 1.5, "b": 1], sameNeighbour: Double.leastNonzeroMagnitude)
    var random = SeededRandom(seed: 7)
    let draws = 4000

    let first = (0..<draws).filter { _ in
      weights.orderedLetters(using: &random, neighbours: ["A": 2, "B": 2]).first == "A"
    }.count

    #expect(abs(Double(first) / Double(draws) - 0.6) < 0.03)
  }
}
