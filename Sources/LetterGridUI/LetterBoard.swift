#if canImport(SwiftUI)
  import LetterGrid
  import SwiftUI

  public struct LetterBoard: View {
    let round: Round
    let style: LetterGridStyle
    let onTouch: (Cell) -> Void
    let onDrag: (Cell) -> Void
    let onRelease: () -> Void
    let onRejectionShown: () -> Void
    @State private var isDragging = false

    public init(
      round: Round, style: LetterGridStyle, onTouch: @escaping (Cell) -> Void,
      onDrag: @escaping (Cell) -> Void, onRelease: @escaping () -> Void,
      onRejectionShown: @escaping () -> Void
    ) {
      self.round = round
      self.style = style
      self.onTouch = onTouch
      self.onDrag = onDrag
      self.onRelease = onRelease
      self.onRejectionShown = onRejectionShown
    }

    private var board: Board { round.board }

    public var body: some View {
      GeometryReader { geometry in
        let side = geometry.size.width / CGFloat(max(board.columns, 1))
        ZStack(alignment: .topLeading) {
          ForEach(bars.indices, id: \.self) { index in
            HighlightBar(span: bars[index].span, side: side, color: bars[index].color)
          }
          if let span = Span(round.rejected) {
            HighlightBar(span: span, side: side, color: style.rejected)
              .transition(.opacity)
          }
          letters(side: side)
        }
        .contentShape(.rect)
        .gesture(drag(side: side))
      }
      .aspectRatio(CGFloat(max(board.columns, 1)) / CGFloat(max(board.rows, 1)), contentMode: .fit)
      .animation(.easeOut(duration: 0.6), value: round.rejected)
      .sensoryFeedback(.impact(weight: .light), trigger: round.selection.count) { old, new in
        new > 0 && new != old
      }
      .sensoryFeedback(.success, trigger: round.found.count) { old, new in new > old }
      .sensoryFeedback(.error, trigger: round.rejected) { _, rejected in !rejected.isEmpty }
      .task(id: round.rejected) {
        guard !round.rejected.isEmpty else { return }
        do {
          try await Task.sleep(for: .seconds(style.rejectionSeconds))
        } catch {
          return
        }
        onRejectionShown()
      }
    }

    private var bars: [(span: Span, color: Color)] {
      let found = board.placements.filter(round.found.contains).map(\.cells) + [round.introduced]
      return found.compactMap(Span.init).map { (span: $0, color: style.found) }
        + round.hintedCells.map { (span: Span(first: $0, last: $0), color: style.hinted) }
        + [Span(round.selection)].compactMap { $0 }.map { (span: $0, color: style.selected) }
    }

    private func letters(side: CGFloat) -> some View {
      VStack(spacing: 0) {
        ForEach(0..<board.rows, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<board.columns, id: \.self) { column in
              Text(String(board[Cell(row: row, column: column)]))
                .font(.system(size: side * 0.5, weight: .semibold, design: .rounded))
                .frame(width: side, height: side)
            }
          }
        }
      }
    }

    private func drag(side: CGFloat) -> some Gesture {
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          if isDragging {
            onDrag(cell(at: value.location, side: side))
          } else {
            isDragging = true
            onTouch(cell(at: value.startLocation, side: side))
          }
        }
        .onEnded { _ in
          isDragging = false
          onRelease()
        }
    }

    private func cell(at point: CGPoint, side: CGFloat) -> Cell {
      Cell(
        row: min(max(Int(point.y / side), 0), board.rows - 1),
        column: min(max(Int(point.x / side), 0), board.columns - 1)
      )
    }
  }

  private struct Span {
    let first: Cell
    let last: Cell

    init(first: Cell, last: Cell) {
      self.first = first
      self.last = last
    }

    init?(_ cells: [Cell]) {
      guard let first = cells.first, let last = cells.last else { return nil }
      self.init(first: first, last: last)
    }
  }

  private struct HighlightBar: View {
    let span: Span
    let side: CGFloat
    let color: Color

    var body: some View {
      let first = span.first
      let last = span.last
      let inset = side * 0.08
      RoundedRectangle(cornerRadius: side / 2 - inset)
        .fill(color)
        .frame(
          width: CGFloat(last.column - first.column + 1) * side - inset * 2,
          height: CGFloat(last.row - first.row + 1) * side - inset * 2
        )
        .offset(x: CGFloat(first.column) * side + inset, y: CGFloat(first.row) * side + inset)
    }
  }
#endif
