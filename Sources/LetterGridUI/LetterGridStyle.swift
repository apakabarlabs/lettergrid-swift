#if canImport(SwiftUI)
  import LetterGrid
  import SwiftUI

  public struct LetterGridStyle {
    public var found: Color
    public var selected: Color
    public var rejected: Color
    public var hinted: Color
    public var foundText: Color
    private var rejectionInterval: SleepInterval

    public var rejectionSeconds: Double {
      get { rejectionInterval.seconds }
      set { rejectionInterval = SleepInterval(enforcing: newValue) }
    }

    var rejectionDelay: Duration { rejectionInterval.duration }

    public init(
      found: Color, selected: Color, rejected: Color, hinted: Color, foundText: Color,
      rejectionSeconds: Double
    ) {
      self.found = found
      self.selected = selected
      self.rejected = rejected
      self.hinted = hinted
      self.foundText = foundText
      self.rejectionInterval = SleepInterval(enforcing: rejectionSeconds)
    }
  }
#endif
