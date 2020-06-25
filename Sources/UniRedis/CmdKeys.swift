/*
 * Copyright 2020 Seznam.cz, a.s.
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
 * Author: Daniel Fojt (daniel.fojt2@firma.seznam.cz)
 */

import Foundation

extension UniRedis {

	public func del(_ keys: [String]) throws -> Int {
		guard let result = try cmd("DEL", params: keys).toInt() else {
			throw UniRedisError.error(detail: "unexpected response")
		}
		return result
	}

	public func exists(_ keys: [String]) throws -> Int {
		guard let result = try cmd("EXISTS", params: keys).toInt() else {
			throw UniRedisError.error(detail: "unexpected response")
		}
		return result
	}

	public func expire(_ key: String, ttl: Int) throws -> Bool {
		return try cmd("EXPIRE", params: [ key, "\(ttl)" ]).toBool()
	}

	public func expireAt(_ key: String, stamp: Int) throws -> Bool {
		return try cmd("EXPIREAT", params: [ key, "\(stamp)" ]).toBool()
	}

	public func keys(_ pattern: String) throws -> [String] {
		return try cmd("KEYS", params: [ pattern ]).toArray()
	}

	public func persist(_ key: String) throws -> Bool {
		return try cmd("PERSIST", params: [ key ]).toBool()
	}

	public func randomkey(_ key: String) throws -> String? {
		return try cmd("RANDOMKEY", params: [ key ]).toString()
	}

	public func rename(_ key: String, newkey: String) throws -> Bool {
		guard let result = try cmd("RENAME", params: [ key, newkey ]).toString(), result == "OK" else {
			return false
		}
		return true
	}

	public func renameNx(_ key: String, newkey: String) throws -> Bool {
		guard let result = try cmd("RENAMENX", params: [ key, newkey ]).toInt(), result == 1 else {
			return false
		}
		return true
	}

	public func touch(_ keys: [String]) throws -> Int {
		guard let result = try cmd("TOUCH", params: keys).toInt() else {
			throw UniRedisError.error(detail: "unexpected response")
		}
		return result
	}

	public func ttl(_ key: String) throws -> Int {
		guard let result = try cmd("TTL", params: [ key ]).toInt() else {
			throw UniRedisError.error(detail: "unexpected response")
		}
		return result
	}

	public func type(_ key: String) throws -> String? {
		return try cmd("TYPE", params: [ key ]).toString()
	}

	public func unlink(_ keys: [String]) throws-> Int {
		guard let result = try cmd("UNLINK", params: keys).toInt() else {
			throw UniRedisError.error(detail: "unexpected response")
		}
		return result
	}

}
