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
