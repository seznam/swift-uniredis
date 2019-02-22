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

public enum UniRedisResponseType: String {
	case error
	case integer
	case string
	case array
}

public struct UniRedisResponse {

	public let type: UniRedisResponseType
	public let content: Any?

	public func throwOnError() throws {
		guard type == .error else {
			return
		}
		if let err = content as? String {
			throw UniRedisError.error(detail: err)
		}
		throw UniRedisError.error(detail: "error response")
	}

	public func toBool() throws -> Bool {
		try throwOnError()
		guard type == .integer else {
			throw UniRedisError.error(detail: "unexpected response type \(type)")
		}
		guard let int = content as? Int else {
			throw UniRedisError.error(detail: "failed to convert response to bool")
		}
		return (int != 0)
	}

	public func toInt() throws -> Int? {
		try throwOnError()
		if type == .integer, let int = content as? Int {
			return int
		} else if type == .string {
			guard let string = content as? String, !string.isEmpty else {
				return nil
			}
			guard let int = Int(string) else {
				throw UniRedisError.error(detail: "failed to convert response to int")
			}
			return int
		}
		throw UniRedisError.error(detail: "unexpected response type \(type)")
	}

	public func toUInt() throws -> UInt? {
		guard let int = try toInt() else {
			return nil
		}
		return UInt(int)
	}

	public func toDouble() throws -> Double? {
		try throwOnError()
		if type == .integer, let int = content as? Int {
			return Double(int)
		} else if type == .string {
			guard let string = content as? String, !string.isEmpty else {
				return nil
			}
			guard let double = Double(string) else {
				throw UniRedisError.error(detail: "failed to convert response to double")
			}
			return double
		}
		throw UniRedisError.error(detail: "unexpected response type \(type)")
	}

	public func toString() throws -> String? {
		try throwOnError()
		guard type == .string else {
			throw UniRedisError.error(detail: "unexpected response type \(type)")
		}
		guard let string = content as? String else {
			return nil
		}
		return string
	}

	public func toArray() throws -> [String] {
		try throwOnError()
		guard type == .array else {
			throw UniRedisError.error(detail: "unexpected response type \(type)")
		}
		guard let arrayresponse = content as? [UniRedisResponse] else {
			throw UniRedisError.error(detail: "failed to convert response to array")
		}
		var array: [String] = []
		for item in arrayresponse {
			guard item.type == .string, let string = item.content as? String else {
				throw UniRedisError.error(detail: "failed to convert array member to string")
			}
			array.append(string)
		}
		return array
	}

	public func toHash() throws -> [String: String] {
		let array = try toArray()
		var hash: [String: String] = [:]
		var idx = 0
		while idx < array.count {
			let key = array[idx]
			idx += 1
			let value = array[idx]
			idx += 1
			hash[key] = value
		}
		return hash
	}

}
