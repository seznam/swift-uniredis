import Foundation

extension String {

	public func match(_ pattern: String) throws -> [String?]? {
		let r = try NSRegularExpression(pattern: pattern)
		let m = r.matches(in: self, range: NSMakeRange(0, self.count))
		guard m.count == 1 else {
			return nil
		}
		var groups = [String?]()
		var g = 1
		while g < m[0].numberOfRanges {
			if m[0].range(at: g).location == NSNotFound {
				groups.append(nil)
			} else {
				let start = String.UTF16Index(encodedOffset: m[0].range(at: g).location)
				let end = String.UTF16Index(encodedOffset: m[0].range(at: g).location + m[0].range(at: g).length)
				groups.append(String(self[start..<end]))
			}
			g += 1
		}
		return groups
	}

}
