#if canImport(SwiftUI)
  import Foundation
  import LetterGrid
  import SwiftUI

  public struct LetterHighlight: View {
    let cells: [Cell]
    let cellSize: CGFloat
    let color: Color

    public init(start: Cell, end: Cell, cellSize: CGFloat, color: Color) {
      self.cells = [start, end]
      self.cellSize = cellSize
      self.color = color
    }

    public init(cells: [Cell], cellSize: CGFloat, color: Color) {
      self.cells = cells
      self.cellSize = cellSize
      self.color = color
    }

    public var body: some View {
      if let first = cells.first {
        if cells.allSatisfy({ $0 == first }) {
          Circle().fill(color)
            .frame(width: cellSize * 0.84, height: cellSize * 0.84)
            .position(center(first))
        } else {
          Path { path in
            path.move(to: center(first))
            for cell in cells.dropFirst() { path.addLine(to: center(cell)) }
          }
          .stroke(
            color, style: StrokeStyle(lineWidth: cellSize * 0.84, lineCap: .round, lineJoin: .round)
          )
        }
      }
    }

    private func center(_ cell: Cell) -> CGPoint {
      CGPoint(x: (CGFloat(cell.column) + 0.5) * cellSize, y: (CGFloat(cell.row) + 0.5) * cellSize)
    }
  }
#endif
