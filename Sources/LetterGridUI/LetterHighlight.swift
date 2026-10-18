#if canImport(SwiftUI)
  import Foundation
  import LetterGrid
  import SwiftUI

  public struct LetterHighlight: View {
    let start: Cell
    let end: Cell
    let cellSize: CGFloat
    let color: Color

    public init(start: Cell, end: Cell, cellSize: CGFloat, color: Color) {
      self.start = start
      self.end = end
      self.cellSize = cellSize
      self.color = color
    }

    public var body: some View {
      let row = CGFloat(end.row - start.row)
      let column = CGFloat(end.column - start.column)
      let distance = (row * row + column * column).squareRoot()
      Capsule()
        .fill(color)
        .frame(width: cellSize * (distance + 0.84), height: cellSize * 0.84)
        .rotationEffect(.radians(atan2(Double(row), Double(column))))
        .position(
          x: CGFloat(start.column + end.column + 1) * cellSize / 2,
          y: CGFloat(start.row + end.row + 1) * cellSize / 2)
    }
  }
#endif
