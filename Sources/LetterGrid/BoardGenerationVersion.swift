public enum BoardGenerationVersion: String, Codable, Sendable {
  case v0p9 = "0.9"
  case v0p12 = "0.12"
  case v0p13 = "0.13"
  case v0p17 = "0.17"
  case v0p18 = "0.18"
  case v0p19 = "0.19"

  public static let current = Self.v0p19

  var fillsConditionally: Bool { self == .v0p17 || self == .v0p18 || self == .v0p19 }
  var acceptsNoise: Bool { self == .v0p13 || fillsConditionally }
}
