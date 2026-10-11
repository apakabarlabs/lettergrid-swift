import Foundation
import Levels

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
  FileHandle.standardError.write(
    Data("usage: level-table <config.yaml> <words.yaml> [seed]\n".utf8))
  exit(2)
}

let configuration = try GameConfiguration.decode(
  String(contentsOfFile: arguments[1], encoding: .utf8))
let words = try WordList.decode(String(contentsOfFile: arguments[2], encoding: .utf8)).words
let seed = arguments.count > 3 ? UInt64(arguments[3]) ?? 1 : 1
let plan = try LevelPlan(configuration: configuration, words: words, seed: seed)

print("level  grid   words  clock  ranks       board")
var unplaceable = 0
var crossed = 0
var standing: [Int: Int] = [:]
for level in plan.levels {
  let ranks = level.words.map(\.rank)
  let board: String
  var grid = "\(level.columns)x\(level.rows)"
  do {
    let built = try plan.board(for: level)
    let cells = built.placements.flatMap(\.cells)
    let down = built.placements.filter { $0.direction == .down }.count
    standing[down, default: 0] += 1
    if Set(cells).count < cells.count { crossed += 1 }
    grid = "\(built.columns)x\(built.rows)"
    board = "ok \(down)v"
  } catch {
    unplaceable += 1
    board = "NO ROOM"
  }
  let span = "\(ranks.min() ?? 0)-\(ranks.max() ?? 0)"
  let line = [
    String(level.number).padding(toLength: 7, withPad: " ", startingAt: 0),
    grid.padding(toLength: 7, withPad: " ", startingAt: 0),
    String(level.words.count).padding(toLength: 7, withPad: " ", startingAt: 0),
    (level.seconds.map { "\($0)s" } ?? "-").padding(toLength: 7, withPad: " ", startingAt: 0),
    span.padding(toLength: 12, withPad: " ", startingAt: 0),
    board.padding(toLength: 9, withPad: " ", startingAt: 0),
    level.words.map(\.word).joined(separator: " "),
  ]
  print(line.joined())
}
let used = plan.levels.reduce(0) { $0 + $1.words.count }
print("\(plan.levels.count) levels, \(used) of \(words.count) words, \(unplaceable) without room")
let spread = standing.keys.sorted().map { "\($0) down: \(standing[$0] ?? 0)" }
print("\(crossed) boards with a crossing; \(spread.joined(separator: ", "))")
let placed = Set(plan.levels.flatMap(\.words).map(\.word))
let left = plan.playable.filter { !placed.contains($0) }
print("\(left.count) playable words on no level: \(left.joined(separator: " "))")
if unplaceable > 0 || !left.isEmpty {
  exit(1)
}
