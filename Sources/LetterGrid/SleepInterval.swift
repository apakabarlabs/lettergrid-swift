package struct SleepInterval {
  package let seconds: Double
  package let duration: Duration

  package init?(seconds: Double) {
    guard seconds.isFinite, seconds > 0, seconds < Double(Int64.max) else { return nil }
    let duration = Duration.seconds(seconds)
    guard duration > .zero else { return nil }
    self.seconds = seconds
    self.duration = duration
  }

  package init(enforcing seconds: Double) {
    guard let interval = Self(seconds: seconds) else {
      preconditionFailure("Sleep seconds must be a positive, representable duration")
    }
    self = interval
  }
}
