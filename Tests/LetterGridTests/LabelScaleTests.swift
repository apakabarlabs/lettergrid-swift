import Testing

@testable import LetterGrid

struct LabelScaleTests {
  @Test(arguments: [1, 2])
  func oneOrTwoLettersKeepTheUsualSize(_ longest: Int) {
    #expect(LabelScale(longest: longest).fontToCell == 0.5)
  }

  @Test func aThreeLetterLabelShrinksEveryCellAlike() {
    #expect(LabelScale(longest: 3).fontToCell == 0.5 * 2 / 3)
  }
}
