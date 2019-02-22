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

extension UniRedis {

	private func parseCRLF(from: Int = 0) -> Int? {
		var position = from
		while (position + 1) < inBuffer.count {
			if inBuffer[position] == 13 && inBuffer[position + 1] == 10 {
				return position
			}
			position = position + 1
		}
		return nil
	}

	func parse() throws -> UniRedisResponse {
		var position: Int = 0
		var crlf: Int?
		var response: UniRedisResponse?
		var staging: [UniRedisResponse]?
		var stagingSize: Int?
		var subStaging: [UniRedisResponse]?
		var subStagingSize: Int?

		while position < inBuffer.count, response == nil {
			let rkey = Character(UnicodeScalar(inBuffer[position]))
			crlf = parseCRLF(from: position)
			guard crlf != nil else {
				throw ParserError.incomplete
			}
			position = position + 1
			let rlen = Array(inBuffer[position..<crlf!])
			let lendata = Data(bytes: rlen, count: rlen.count)
			guard let content = String(data: lendata, encoding: .utf8) else {
				throw ParserError.invalid(at: position)
			}
			var part: UniRedisResponse?
			switch rkey {
			case "-":
				part = UniRedisResponse(type: .error, content: content)
			case ":":
				guard let int = Int(content) else {
					throw ParserError.invalid(at: position)
				}
				part = UniRedisResponse(type: .integer, content: int)
			case "+":
				part = UniRedisResponse(type: .string, content: content)
			case "$":
				guard let len = Int(content) else {
					throw ParserError.invalid(at: position)
				}
				if len == -1 {
					part = UniRedisResponse(type: .string, content: nil)
				} else {
					position = crlf! + 2
					crlf! = position + len
					guard crlf! + 1 < inBuffer.endIndex else {
						throw ParserError.incomplete
					}
					guard inBuffer[crlf!] == 13, inBuffer[crlf! + 1] == 10 else {
						throw ParserError.invalid(at: crlf!)
					}
					let rbulk = Array(inBuffer[position..<crlf!])
					let bulk = Data(bytes: rbulk, count: rbulk.count)
					part = UniRedisResponse(type: .string, content: String(data: bulk, encoding: .utf8))
				}
			case "*":
				guard let len = Int(content) else {
					throw ParserError.invalid(at: position)
				}
				if len == -1 {
					part = UniRedisResponse(type: .array, content: nil)
				} else if len == 0 {
					part = UniRedisResponse(type: .array, content: [UniRedisResponse]())
				} else if staging == nil {
					staging = [UniRedisResponse]()
					stagingSize = len
				} else {
					subStaging = [UniRedisResponse]()
					subStagingSize = len
				}
			default:
				throw ParserError.invalid(at: position)
			}
			position = crlf! + 2
			if let p = part, let ss = subStagingSize {
				subStaging!.append(p)
				subStagingSize = ss - 1
				if subStagingSize! == 0 {
					part = UniRedisResponse(type: .array, content: subStaging!)
					subStaging = nil
					subStagingSize = nil
				} else {
					part = nil
				}
			}
			if let p = part {
				if let ss = stagingSize {
					staging!.append(p)
					stagingSize = ss - 1
					if stagingSize! == 0 {
						response = UniRedisResponse(type: .array, content: staging!)
					}
				} else {
					response = p
				}
			}
		}

		if let r = response {
			inBuffer.removeSubrange(0..<position)
			return r
		}

		throw ParserError.incomplete
	}

}
