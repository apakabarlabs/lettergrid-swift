extension Character {
  public var cellUppercased: Character {
    let upper = uppercased()
    return upper.count == 1 ? Character(upper) : self
  }
}

extension String {
  public var cellUppercased: String { String(map(\.cellUppercased)) }
}
