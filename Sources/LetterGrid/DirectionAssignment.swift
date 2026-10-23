struct WordDirection {
  let index: Int
  let direction: Direction
}

struct DirectionAssignment {
  enum VerticalOrder {
    case shuffled
    case shortestFirst
  }

  let columns: Int
  let directions: [Direction]
  let downWords: ClosedRange<Int>
  let firstDirection: Direction?

  var usesForwardOrthogonalLayout: Bool {
    Set(directions).isSubset(of: [.right, .down]) && firstDirection == nil
  }

  func assignments(
    for words: [String], using random: inout SeededRandom, order: VerticalOrder = .shuffled
  ) -> [WordDirection]? {
    guard let standing = verticalIndices(for: words, using: &random, order: order) else {
      return nil
    }
    let vertical = Set(standing)
    let indices =
      order == .shortestFirst
      ? standing + words.indices.filter { !vertical.contains($0) }
      : Array(words.indices)
    var assigned: [WordDirection] = []
    for index in indices {
      let direction: Direction?
      if order == .shortestFirst {
        direction = vertical.contains(index) ? .down : .right
      } else if index == 0, let firstDirection {
        direction = firstDirection
      } else {
        direction = directions.filter { $0.isVertical == vertical.contains(index) }
          .randomElement(using: &random)
      }
      guard let direction else { return nil }
      assigned.append(WordDirection(index: index, direction: direction))
    }
    return assigned
  }

  private func verticalIndices(
    for words: [String], using random: inout SeededRandom, order: VerticalOrder
  ) -> [Int]? {
    if let firstDirection {
      guard directions.contains(firstDirection), let first = words.first,
        firstDirection.isVertical || first.count <= columns
      else { return nil }
    }
    let upright = directions.contains(where: \.isVertical)
    let hasOther = directions.contains { !$0.isVertical }
    let forced = words.indices.filter {
      words[$0].count > columns || !hasOther || ($0 == 0 && firstDirection?.isVertical == true)
    }
    let maximum = upright ? min(downWords.upperBound, words.count, columns) : 0
    let minimum = max(downWords.lowerBound, forced.count)
    guard minimum <= maximum else { return nil }
    var optional = words.indices.filter {
      !forced.contains($0)
        && !($0 == 0 && firstDirection != nil && firstDirection?.isVertical == false)
    }.shuffled(using: &random)
    if order == .shortestFirst { optional.sort { words[$0].count < words[$1].count } }
    guard minimum <= forced.count + optional.count else { return nil }
    let count = Int.random(
      in: minimum...min(maximum, forced.count + optional.count), using: &random)
    return forced + optional.prefix(count - forced.count)
  }
}
