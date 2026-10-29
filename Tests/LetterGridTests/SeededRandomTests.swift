import Foundation
import Testing
import Yams

@testable import LetterGrid

private struct SeededRandomCase: Decodable {
  let name: String
  let seed: UInt64
  let next: [UInt64]?
  let below: Int?
  let integers: [Int]?
  let doubleBelow: Double?
  let doubles: [Double]?
  let shuffle: Int?
  let order: [Int]?
  let from: Int?
  let through: Int?
  let pickFrom: Int?
  let picks: [Int]?

  enum CodingKeys: String, CodingKey {
    case name, seed, next, below, integers, doubles, shuffle, order, from, through, picks
    case doubleBelow = "double_below"
    case pickFrom = "pick_from"
  }
}

struct SeededRandomTests {
  private static func cases() throws -> [SeededRandomCase] {
    let url = try #require(
      Bundle.module.url(
        forResource: "seeded-random", withExtension: "yaml", subdirectory: "Fixtures"))
    return try YAMLDecoder().decode([SeededRandomCase].self, from: Data(contentsOf: url))
  }

  @Test func everyDrawFollowsTheRecordedSequence() throws {
    for item in try Self.cases() {
      var random = SeededRandom(seed: item.seed)
      if let next = item.next {
        #expect(next.map { _ in random.next() } == next, "\(item.name)")
      }
      if let below = item.below, let integers = item.integers {
        #expect(integers.map { _ in random.nextInt(below: below) } == integers, "\(item.name)")
      }
      if let upper = item.doubleBelow, let doubles = item.doubles {
        #expect(doubles.map { _ in random.nextDouble(below: upper) } == doubles, "\(item.name)")
      }
      if let count = item.shuffle, let order = item.order {
        #expect(random.shuffled(Array(0..<count)) == order, "\(item.name)")
      }
      if let from = item.from, let through = item.through, let integers = item.integers {
        #expect(
          integers.map { _ in random.nextInt(in: from...through) } == integers, "\(item.name)")
      }
      if let count = item.pickFrom, let picks = item.picks {
        #expect(picks.map { _ in random.pick(Array(0..<count)) } == picks, "\(item.name)")
      }
    }
  }

  @Test func theDrawsMatchTheStandardLibraryTheyReplace() {
    for seed in UInt64(0)..<200 {
      var ours = SeededRandom(seed: seed)
      var standard = SeededRandom(seed: seed)
      let count = Int(seed % 17) + 1
      #expect(ours.nextInt(below: count) == Int.random(in: 0..<count, using: &standard))
      #expect(ours.nextInt(in: 0...count) == Int.random(in: 0...count, using: &standard))
      #expect(ours.nextDouble(below: 3.5) == Double.random(in: 0..<3.5, using: &standard))
      #expect(
        ours.shuffled(Array(0..<count)) == Array(0..<count).shuffled(using: &standard))
      #expect(ours.pick(Array(0..<count)) == Array(0..<count).randomElement(using: &standard))
    }
  }
}
