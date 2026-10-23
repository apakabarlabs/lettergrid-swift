#if canImport(SwiftUI)
  import LetterGrid
  import SwiftUI

  public struct LetterBoard: View {
    let round: Round
    let missed: Placement?
    let style: LetterGridStyle
    let onTouch: (Cell) -> Void
    let onDrag: (Cell) -> Void
    let onRelease: () -> Void
    let onRejectionShown: () -> Void
    let label: (Character) -> String
    @State private var isDragging = false

    public init(
      round: Round, missed: Placement? = nil, style: LetterGridStyle,
      label: @escaping (Character) -> String = { String($0) },
      onTouch: @escaping (Cell) -> Void,
      onDrag: @escaping (Cell) -> Void, onRelease: @escaping () -> Void,
      onRejectionShown: @escaping () -> Void
    ) {
      self.round = round
      self.missed = missed
      self.style = style
      self.label = label
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
            LetterHighlight(
              start: bars[index].span.first, end: bars[index].span.last,
              cellSize: side, color: bars[index].color)
          }
          if let span = Span(round.rejected) {
            LetterHighlight(
              start: span.first, end: span.last, cellSize: side, color: style.rejected
            )
            .transition(.opacity)
          }
          if let missed, let span = Span(missed.cells) {
            LetterHighlight(
              start: span.first, end: span.last, cellSize: side, color: style.rejected)
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
          try await Task.sleep(for: style.rejectionDelay)
        } catch is CancellationError {
          return
        } catch {
          preconditionFailure("Unexpected rejection delay failure: \(error)")
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
      let scale = LabelScale(longest: board.letters.joined().map { label($0).count }.max() ?? 1)
        .fontToCell
      return VStack(spacing: 0) {
        ForEach(0..<board.rows, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<board.columns, id: \.self) { column in
              Text(label(board[Cell(row: row, column: column)]))
                .font(.system(size: side * scale, weight: .semibold, design: .rounded))
                .frame(width: side, height: side)
            }
          }
        }
      }
    }

    private func drag(side: CGFloat) -> some Gesture {
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          let point = isDragging ? value.location : value.startLocation
          guard let cell = cell(at: point, side: side) else { return }
          if isDragging {
            onDrag(cell)
          } else {
            isDragging = true
            onTouch(cell)
          }
        }
        .onEnded { _ in
          guard isDragging else { return }
          isDragging = false
          onRelease()
        }
    }

    private func cell(at point: CGPoint, side: CGFloat) -> Cell? {
      guard side.isFinite, side > 0, point.x.isFinite, point.y.isFinite,
        board.rows > 0, board.columns > 0
      else { return nil }
      return Cell(
        row: Int(min(max(point.y / side, 0), CGFloat(board.rows - 1))),
        column: Int(min(max(point.x / side, 0), CGFloat(board.columns - 1)))
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

#endif
