import LetterGrid
import Testing

struct WordRuleGeometryTests {
  @Test func straightPathsRespectBothBounds() {
    let right = WordRule(startDirections: [.right])
    #expect(right.canFit(length: 7, columns: 7, maximumRows: 7))
    #expect(!right.canFit(length: 8, columns: 7, maximumRows: 7))
    let down = WordRule(startDirections: [.down])
    #expect(!down.canFit(length: 8, columns: 7, maximumRows: 7))
    #expect(down.canFit(length: 8, columns: 1))
  }

  @Test func bendsFitLongWordsAndRequireTheExactTurnCount() {
    #expect(
      WordRule(startDirections: [.right], turns: 1)
        .canFit(length: 8, columns: 7, maximumRows: 7))
    #expect(
      WordRule(startDirections: [.right], turns: 2)
        .canFit(length: 4, columns: 2, maximumRows: 2))
    #expect(
      WordRule(startDirections: [.right], turns: 3)
        .canFit(length: 5, columns: 2, maximumRows: 3))
    #expect(
      !WordRule(startDirections: [.right], turns: 1)
        .canFit(length: 2, columns: 7, maximumRows: 7))
    #expect(
      !WordRule(startDirections: [.right], turns: 3)
        .canFit(length: 5, columns: 2, maximumRows: 2))
  }

  @Test func diagonalBendsNeedRoomInBothAxes() {
    let diagonal = WordRule(startDirections: [.upRight], turns: 1)
    #expect(!diagonal.canFit(length: 3, columns: 2, maximumRows: 2))
    #expect(diagonal.canFit(length: 3, columns: 3, maximumRows: 2))
    #expect(
      !WordRule(startDirections: [.upRight])
        .canFit(length: 4, columns: 3))
  }

  @Test func invalidGeometryIsRejected() {
    let rule = WordRule(startDirections: [.right])
    #expect(!rule.canFit(length: 0, columns: 7))
    #expect(!rule.canFit(length: 1, columns: 7))
    #expect(!rule.canFit(length: 3, columns: 0))
    #expect(!rule.canFit(length: 3, columns: 7, maximumRows: 0))
    #expect(!WordRule(startDirections: []).canFit(length: 3, columns: 7))
    #expect(
      !WordRule(startDirections: [.right], turns: 4)
        .canFit(length: 6, columns: 7))
  }
}
