import Testing

@testable import LetterGrid

struct BandedBoardTests {
  private let alphabet = Array("ABCDEFGH")
  private let directionSets: [[Direction]] = [
    [.right], [.down], [.right, .down], [.right, .down, .downRight],
    [.right, .down, .downRight, .downLeft], [.downRight, .downLeft],
    [.left], [.up], [.right, .left], [.down, .up], [.upLeft, .upRight],
    Direction.allCases,
  ]

  private func generator(
    directions: [Direction], downWords: ClosedRange<Int>, maxRows: Int? = nil
  ) throws -> BoardGenerator {
    var weights = Dictionary(uniqueKeysWithValues: alphabet.map { (String($0), 1.0) })
    weights["z"] = 0.5
    return BoardGenerator(
      size: BoardSize(columns: 7, rows: 7, maxRows: maxRows),
      rules: [.straight(directions)],
      filler: Filler(weights: try LetterWeights(weights)),
      limits: PlacementLimits(downWords: downWords)
    )
  }

  private func words(using random: inout SeededRandom) -> [String] {
    (0..<Int.random(in: 1...3, using: &random)).map { _ in
      String(
        (0..<Int.random(in: 2...6, using: &random)).map { _ in
          alphabet.randomElement(using: &random) ?? "A"
        })
    }
  }

  @Test func everyAcceptedRequestGetsABoardWithEachWordExactlyOnce() throws {
    var random = SeededRandom(seed: 2026)
    var built = 0
    for directions in directionSets {
      for downWords in [0...2, 1...2] {
        let generator = try generator(directions: directions, downWords: downWords)
        for _ in 0..<150 {
          let words = words(using: &random)
          let first: Direction? =
            Bool.random(using: &random) ? nil : directions.randomElement(using: &random)
          let request: BoardRequest
          do {
            request = try generator.request(for: words, firstRule: first.map { .straight([$0]) })
          } catch {
            continue
          }
          let board = request.board(seed: random.next())
          built += 1
          #expect(board.columns == 7)
          #expect(board.rows >= 7)
          #expect(board.placements.map(\.word) == request.words)
          for word in request.words {
            #expect(board.occurrences(of: word, along: directions) == 1, "\(request.words)")
          }
          for placement in board.placements {
            #expect(directions.contains(placement.direction))
            #expect(board.text(along: placement.cells) == placement.word)
          }
          if let first { #expect(board.placements.first?.direction == first) }
          #expect(
            downWords.contains(board.placements.filter(\.direction.isVertical).count)
              || !directions.contains(where: \.isVertical))
        }
      }
    }
    #expect(built > 500)
  }

  @Test func everyAcceptedBoundedRequestKeepsItsWordsUniqueInsideTheSquare() throws {
    var random = SeededRandom(seed: 2027)
    var built = 0
    for directions in directionSets {
      for downWords in [0...2, 1...2] {
        let generator = try generator(directions: directions, downWords: downWords, maxRows: 7)
        for _ in 0..<30 {
          let words = words(using: &random)
          let first = directions.randomElement(using: &random)
          let request: BoardRequest
          do {
            request = try generator.request(for: words, firstRule: first.map { .straight([$0]) })
          } catch BoardGenerator.Failure.noRoom(_, _, _) {
            continue
          }
          let board = request.board(seed: random.next())
          built += 1
          #expect(board.columns == 7 && board.rows == 7)
          #expect(board.placements.map(\.word) == request.words)
          for word in request.words {
            #expect(board.occurrences(of: word, along: directions) == 1)
          }
          #expect(board.placements.allSatisfy { directions.contains($0.direction) })
          #expect(board.placements.first?.direction == first)
          #expect(downWords.contains(board.placements.filter(\.direction.isVertical).count))
        }
      }
    }
    #expect(built > 100)
  }

  @Test func downWordsStandSideBySideSoTheBoardIsOnlyAsTallAsTheLongest() throws {
    let directions: [Direction] = [.right, .down, .downRight]
    let generator = try generator(directions: directions, downWords: 2...2)
    let request = try generator.request(
      for: ["ABCDEF", "BADCFE", "CAFEBD"], firstRule: .straight([.downRight]))

    let board = request.board(seed: 7)

    #expect(board.rows <= 13)
    #expect(board.placements.filter { $0.direction == .down }.count == 2)
    for word in request.words {
      #expect(board.occurrences(of: word, along: directions) == 1)
    }
  }

  @Test func aWordInsideAnotherIsRejectedBecauseItWouldReadTwice() throws {
    let generator = try generator(directions: [.right, .down], downWords: 0...2)

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["CAB", "CABBA"])
    }
  }

  @Test func wordsThatUseEveryFillerLetterAreRejected() throws {
    let generator = BoardGenerator(
      size: BoardSize(columns: 7, rows: 7),
      rules: [.straight([.right, .down])],
      filler: Filler(weights: try LetterWeights(["a": 1, "b": 1]))
    )

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["AB", "BBA"])
    }
  }
}
