#if canImport(SwiftUI)
  import LetterGrid
  import SwiftUI

  public struct HiddenWordList: View {
    let round: Round
    let style: LetterGridStyle
    let hiddenWordLabel: @MainActor (Int) -> String
    @ScaledMetric(relativeTo: .title3) private var letterWidth = 22

    public init(
      round: Round, style: LetterGridStyle, hiddenWordLabel: @escaping @MainActor (Int) -> String
    ) {
      self.round = round
      self.style = style
      self.hiddenWordLabel = hiddenWordLabel
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(round.board.placements.enumerated()), id: \.offset) { index, placement in
          HStack(spacing: 10) {
            Text("\(index + 1).")
              .foregroundStyle(.secondary)
            word(placement, isShownByGame: isShownByGame(index))
          }
        }
      }
      .font(.title3.monospaced())
      .frame(maxWidth: .infinity)
    }

    private func isShownByGame(_ index: Int) -> Bool {
      round.showsFirstWord && index == 0 && round.phase != .introducing
    }

    @ViewBuilder
    private func word(_ placement: Placement, isShownByGame: Bool) -> some View {
      let shown = round.shownLetters(of: placement)
      if isShownByGame {
        letters(shown)
          .foregroundStyle(style.shownByGame)
          .accessibilityLabel(placement.word)
      } else if round.found.contains(placement) {
        letters(shown)
          .accessibilityLabel(placement.word)
      } else {
        letters(shown)
          .accessibilityLabel(hiddenWordLabel(shown.count))
      }
    }

    private func letters(_ letters: [Character?]) -> some View {
      HStack(spacing: 0) {
        ForEach(letters.indices, id: \.self) { index in
          Text(letters[index].map(String.init) ?? "•")
            .frame(width: letterWidth)
        }
      }
      .accessibilityElement(children: .ignore)
    }
  }
#endif
