import Testing

@testable import LetterGrid

struct LetterWeightsTests {
  @Test(arguments: [Double.infinity, -.infinity, .nan])
  func nonFiniteWeightsAreRejected(_ weight: Double) {
    #expect(throws: LetterWeights.Failure.notFinite("a")) {
      try LetterWeights(["a": weight])
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
}
