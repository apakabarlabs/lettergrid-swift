import Foundation
import LetterGrid

@MainActor
enum BoundedProfile {
  enum Failure: Error {
    case arguments
    case input(Int)
    case interrupted
  }
  private enum Operation: String { case request, board }

  static func run(_ arguments: [String]) throws {
    guard (4...5).contains(arguments.count),
      let version = BoardGenerationVersion(rawValue: arguments[0]),
      [.v0p18, .v0p19].contains(version),
      let operation = Operation(rawValue: arguments[1]),
      let index = Int(arguments[2]), let repetitions = Int(arguments[3]), repetitions > 0,
      arguments.count == 4 || arguments[4] == "--wait"
    else { throw Failure.arguments }
    let workload = try TurnedBoards.workload()
    let inputs = try BoundedBoards.inputs(workload)
    guard inputs.indices.contains(index) else { throw Failure.input(index) }
    let input = inputs[index]
    let generator = workload.generator(version)
    let request = try generator.request(for: input.words, firstRule: workload.rules.last)
    let dictionary = BoardDictionary(workload.words)
    let line =
      "PROFILE_READY pid=\(ProcessInfo.processInfo.processIdentifier); "
      + "version=\(version.rawValue); operation=\(operation.rawValue); input=\(index); "
      + "words=\(input.words.joined(separator: " ")); repetitions=\(repetitions)\n"
    FileHandle.standardOutput.write(Data(line.utf8))
    if arguments.count == 5, readLine() == nil { throw Failure.interrupted }
    try LetterGridBenchmarks.measureWorst(
      "profile \(version.rawValue) \(operation.rawValue) input=\(index)", iterations: repetitions,
      sampleLabel: "repetition"
    ) { _ in
      switch operation {
      case .request:
        return try generator.request(for: input.words, firstRule: workload.rules.last).words.count
      case .board:
        return request.board(seed: UInt64(index + 1), dictionary: dictionary).rows
      }
    }
  }
}
