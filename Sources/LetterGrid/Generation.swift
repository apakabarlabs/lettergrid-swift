import Foundation
import Yams

struct Generation: Decodable {
  struct Packing: Decodable {
    let nodeLimit: Int
    let growingHeightNodeLimit: Int
    let crossingRestarts: Int
  }

  struct Shapes: Decodable {
    let shapeLimit: Int
    let visitLimit: Int
  }

  struct Noise: Decodable {
    let visitLimit: Int
  }

  struct Fill: Decodable {
    let seeds: Int
    let stepsPerChoice: Int
    let completedCandidates: Int
  }

  struct Reveal: Decodable {
    let frameSeconds: Double
    let travelShare: Double
  }

  let supportedTurns: [Int]
  let packing: Packing
  let shapes: Shapes
  let noise: Noise
  let fill: Fill
  let reveal: Reveal

  static let settings: Generation = {
    guard let url = Bundle.module.url(forResource: "generation", withExtension: "yaml") else {
      preconditionFailure("generation.yaml is missing from the LetterGrid bundle")
    }
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      let settings = try YAMLDecoder().decode(Generation.self, from: text)
      precondition(settings.supportedTurns.count == 2, "supportedTurns names a first and last")
      return settings
    } catch {
      preconditionFailure("generation.yaml cannot be read: \(error)")
    }
  }()
}
