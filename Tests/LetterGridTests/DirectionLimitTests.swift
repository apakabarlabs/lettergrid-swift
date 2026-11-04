import Testing

@testable import LetterGrid

struct DirectionLimitTests {
  @Test func aRejectedCompleteLayoutReleasesDirectionCapacity() throws {
    let words = ["CAT", "DOG"]
    var packing = PathPacking(
      columns: 5, rows: 5, rules: [WordRule(startDirections: [.right, .down])],
      maxWordsPerDirection: 1)
    packing.crossingRestarts = 1
    guard case .placed(let initial) = packing.pack(words) else {
      Issue.record("The unconstrained completion must fit")
      return
    }
    let rejected = initial[0].cells
    packing.completes = { placements, _ in
      placements[0].cells == rejected ? .doesNotFit : .fits
    }
    guard case .placed(let retried) = packing.pack(words) else {
      Issue.record("Backtracking must release the rejected layout's direction counts")
      return
    }
    #expect(retried[0].cells != rejected)
    #expect(Set(retried.map(\.direction)) == [.right, .down])
  }

  @Test(arguments: Direction.allCases, 0...3)
  func bentWordsCountTheirFirstSegment(direction: Direction, turns: Int) throws {
    let rules = [WordRule(startDirections: [direction, direction.opposite], turns: turns)]
    let leading = [
      WordRule(startDirections: [direction], turns: turns),
      WordRule(startDirections: [direction], turns: turns),
    ]
    let words = ["PLANE", "ORBIT", "DUSKY"]
    for maximumRows: Int? in [7, nil] {
      let generator = BoardGenerator(
        size: BoardSize(columns: 7, rows: 7, maxRows: maximumRows),
        rules: rules,
        filler: Filler(weights: try LetterWeights(["q": 1, "w": 1])),
        limits: PlacementLimits(maxWordsPerDirection: 2)
      )
      try generator.checkPlacement(for: words, leadingRules: leading)
      let request = try generator.placementRequest(for: words, leadingRules: leading)
      for seed in UInt64(0)...2 {
        let placements = request.targets(seed: seed).placements
        #expect(placements.prefix(2).allSatisfy { $0.direction == direction })
        #expect(placements.last?.direction == direction.opposite)
        #expect(placements.allSatisfy { $0.turns == turns })
      }
    }
  }

  @Test func straightInitializerEnforcesTheSameLimit() throws {
    let filler = try LetterWeights(["q": 1, "w": 1])
    let generator = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7, maxRows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: filler),
      limits: PlacementLimits(maxWordsPerDirection: 1)
    )
    let words = ["CAT", "DOG", "SUN"]
    #expect(!generator.accepts(words))
    #expect(throws: BoardGenerator.Failure.noRoom(words: words, columns: 7, rows: 7)) {
      try generator.checkPlacement(for: words)
    }
    let request = try generator.request(for: ["CAT", "DOG"], firstRule: .straight([.right]))
    for seed in UInt64(0)...2 {
      #expect(Set(request.board(seed: seed).placements.map(\.direction)) == [.right, .down])
    }
  }

  @Test func aLimitChangesRequestIdentityWithoutChangingUnlimitedDefaults() throws {
    let filler = try LetterWeights(["q": 1, "w": 1])
    let unlimited = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: filler)
    )
    let explicitNil = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: filler),
      limits: PlacementLimits(maxWordsPerDirection: nil)
    )
    let limited = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: filler),
      limits: PlacementLimits(maxWordsPerDirection: 2)
    )
    #expect(unlimited == explicitNil)
    #expect(unlimited != limited)
    let words = ["CAT", "DOG", "SUN"]
    let original = try unlimited.request(for: words)
    let same = try explicitNil.request(for: words)
    let capped = try limited.request(for: words)
    #expect(original == same)
    #expect(original != capped)
    for seed in UInt64(0)...2 {
      #expect(original.board(seed: seed) == same.board(seed: seed))
    }
  }
}
