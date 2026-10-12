#if canImport(SwiftUI)
  import SwiftUI

  public struct LetterGridStyle {
    public var found: Color
    public var selected: Color
    public var rejected: Color
    public var hinted: Color
    public var foundText: Color
    public var rejectionSeconds: Double

    public init(
      found: Color, selected: Color, rejected: Color, hinted: Color, foundText: Color,
      rejectionSeconds: Double
    ) {
      self.found = found
      self.selected = selected
      self.rejected = rejected
      self.hinted = hinted
      self.foundText = foundText
      self.rejectionSeconds = rejectionSeconds
    }
  }
#endif
