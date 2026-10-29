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

  @Test func aSingleDrawMatchesTheFirstOrderedChoiceIncludingRescaledWeights() throws {
    let cases: [(LetterWeights, [Character: Int])] = [
      (try LetterWeights(["a": 8, "b": 2, "c": 1], sameNeighbour: 0.2), ["A": 4, "B": 1]),
      (try LetterWeights(["a": .greatestFiniteMagnitude, "b": .greatestFiniteMagnitude]), [:]),
      (
        try LetterWeights(
          ["a": 1, "b": .leastNonzeroMagnitude], sameNeighbour: .leastNonzeroMagnitude),
        ["A": 8, "B": 8]
      ),
      (try LetterWeights(["a": 1, "A": 2, "b": 3]), [:]),
    ]
    for (weights, neighbours) in cases {
      for seed: UInt64 in 1...100 {
        var direct = SeededRandom(seed: seed)
        var ordered = SeededRandom(seed: seed)
        #expect(
          weights.randomLetter(using: &direct, neighbours: neighbours)
            == weights.orderedLetters(using: &ordered, neighbours: neighbours).first)
      }
    }
  }

  @Test func aSingleDrawDoesNotConsumeTheRestOfThePermutation() throws {
    let weights = try LetterWeights(["a": 8, "b": 2, "c": 1])
    for seed: UInt64 in 1...100 {
      var direct = SeededRandom(seed: seed)
      var expected = SeededRandom(seed: seed)
      _ = weights.randomLetter(using: &direct)
      _ = Double.random(in: 0..<11, using: &expected)
      #expect(direct.next() == expected.next())
    }
  }
}
