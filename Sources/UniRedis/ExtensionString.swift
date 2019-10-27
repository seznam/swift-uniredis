/*
 * Copyright 2017-2018 Seznam.cz, a.s.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Author: Daniel Bilik (daniel.bilik@firma.seznam.cz)
 */

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
				let start = String.UTF16View.Index(encodedOffset: m[0].range(at: g).location)
				let end = String.UTF16View.Index(encodedOffset: m[0].range(at: g).location + m[0].range(at: g).length)
				groups.append(String(self[start..<end]))
			}
			g += 1
		}
		return groups
	}

}
