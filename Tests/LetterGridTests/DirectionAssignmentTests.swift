import Testing

@testable import LetterGrid

struct DirectionAssignmentTests {
  @Test func orthogonalOrderKeepsForcedWordsThenTheShortestOptionalWords() throws {
    let assignment = DirectionAssignment(
      columns: 5, directions: [.right, .down], downWords: 2...2, firstDirection: nil)
    for seed: UInt64 in 1...20 {
      var random = SeededRandom(seed: seed)
      let assigned = try #require(
        assignment.assignments(
          for: ["CATHEDRAL", "CAT", "DOGS", "BIRD"], using: &random, order: .shortestFirst))
      #expect(assigned.map(\.index) == [0, 1, 2, 3])
      #expect(assigned.map(\.direction) == [.down, .down, .right, .right])
    }
  }

  @Test func generalAssignmentKeepsInputOrderAndTheRequiredFirstDirection() throws {
    let assignment = DirectionAssignment(
      columns: 5, directions: Direction.allCases, downWords: 1...2, firstDirection: .left)
    for seed: UInt64 in 1...20 {
      var random = SeededRandom(seed: seed)
      let assigned = try #require(
        assignment.assignments(for: ["CAT", "DOG", "CATHEDRAL"], using: &random))
      #expect(assigned.map(\.index) == [0, 1, 2])
      #expect(assigned[0].direction == .left)
      #expect(assigned[2].direction.isVertical)
      #expect((1...2).contains(assigned.filter(\.direction.isVertical).count))
    }
  }

  @Test func anImpossibleQuotaIsRejectedByEitherOrdering() {
    let assignment = DirectionAssignment(
      columns: 5, directions: [.right, .down], downWords: 2...2, firstDirection: nil)
    for order in [DirectionAssignment.VerticalOrder.shuffled, .shortestFirst] {
      var random = SeededRandom(seed: 42)
      #expect(assignment.assignments(for: ["CAT"], using: &random, order: order) == nil)
    }
  }
}
