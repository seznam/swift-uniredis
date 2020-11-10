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
import UniSocket

public enum UniRedisError: Error {
	case error(detail: String)
}

public func ==(lhs: UniRedis, rhs: UniRedis) -> Bool {
	return (lhs.host == rhs.host) && (lhs.port == rhs.port) && (lhs.db == rhs.db) && (lhs.sentinel == rhs.sentinel)
}

public class UniRedis {

	public let host: String
	public var port: Int32 = 6379
	public var db: Int = 0
	public let sentinel: Bool
	public var username: String?
	public var password: String?
	public var timeout: UniSocketTimeout = (connect: 4, read: 4, write: 4)

	var sock: UniSocket?
	var inBuffer = [UInt8]()
	var outBuffer = Data()
	var inTransaction: Bool = false
	var inPipeline: Bool = false
	var pipelineCount: Int = 0
	var subscribedChannel: Set<String> = []
	var subscribedPattern: Set<String> = []

	enum ParserError: Error {
		case incomplete
		case invalid(at: Int)
	}

	public init(_ url: String) throws {
		guard let match = try url.match("^(?:redis(\\+sentinel)?://)?(?:([^@]+)@)?([^:/]+)(?::([0-9]+))?(?:/([0-9]+))?$"), match.count == 5 else {
		sentinel = (match[0] != nil) ? true:false
		host = match[2]!
		if let m = match[3] {
			port = Int32(m)!
		}
		if let m = match[4] {
			db = Int(m)!
		}
		if let m = match[1] {
			if let auth = try m.match("^(.+):(.+)?$") {
			    username = auth[1]
			    password = auth[2]
			} else {
			    password = m
			}
		}
	}

	public init(host: String, port: Int32 = 6379, db: Int = 0, sentinel: Bool = false, username: String? = nil, password: String? = nil) {
		self.host = host
		self.port = port
		self.db = db
		self.sentinel = sentinel
		self.username = username
		self.password = password
	}

	public init(_ redis: UniRedis) {
		self.host = redis.host
		self.port = redis.port
		self.db = redis.db
		self.sentinel = redis.sentinel
		self.password = redis.password
	}

	public func connect() throws -> Void {
		guard sock == nil else {
			throw UniRedisError.error(detail: "redis already connected")
		}
		do {
			let (masterHost, masterPort) = try getMasterFromSentinel()
			sock = try UniSocket(type: .tcp, peer: masterHost, port: masterPort, timeout: timeout)
			try sock!.attach()
			if let username = username {
				_ = try cmd("AUTH", params: [ username, password ?? "" ])
			}
			else if let p = password {
				_ = try cmd("AUTH", params: [ p ])
			}
			_ = try cmd("SELECT", params: [ "\(db)" ])
		} catch UniSocketError.error(let detail) {
			sock = nil
			throw UniRedisError.error(detail: "socket error while connecting to redis, \(detail)")
		} catch UniRedisError.error(let detail) {
			sock = nil
			throw UniRedisError.error(detail: detail)
		}
	}

	deinit {
		disconnect()
	}

	public func disconnect() -> Void {
		if sock != nil {
			_ = try? cmd("QUIT")
			sock = nil
		}
		flushBuffers()
	}

	public func flushBuffers() -> Void {
		inBuffer = [UInt8]()
		outBuffer = Data()
	}

	public func cmd(_ command: String, params: [String]? = nil, debug: Bool = false) throws -> UniRedisResponse {
		var parts: [String]
		if let p = params {
			parts = p
		} else {
			parts = [String]()
		}
		parts.insert(command, at: 0)
		var output = "*\(parts.count)\r\n"
		for part in parts {
			let partbytes = [UInt8](part.utf8)
			output.append("$\(partbytes.count)\r\n")
			output.append("\(part)\r\n")
		}
		if debug {
			print("resp request:")
			print(output)
		}
		guard let outputData = output.data(using: .utf8) else {
			throw UniRedisError.error(detail: "failed to compose redis request")
		}
		outBuffer.append(outputData)
		if inPipeline {
			pipelineCount += 1
			return UniRedisResponse(type: .string, content: "enqueued to buffer")
		}
		try sendBuffer()
		inBuffer.removeAll(keepingCapacity: true)
		return try readResponse(debug: debug)
	}

	func sendBuffer() throws -> Void {
		guard let s = sock else {
			throw UniRedisError.error(detail: "redis not connected")
		}
		do {
			try s.send(outBuffer)
			outBuffer.removeAll(keepingCapacity: true)
		} catch UniSocketError.error(let detail) {
			throw UniRedisError.error(detail: "socket error while sending request, \(detail)")
		}
	}

	func readResponse(debug: Bool = false) throws -> UniRedisResponse {
		guard let s = sock else {
			throw UniRedisError.error(detail: "redis not connected")
		}
		var response: UniRedisResponse?
		while response == nil {
			do {
				if debug, let dbg = String(data: Data(bytes: inBuffer, count: inBuffer.count), encoding: .utf8) {
					print("input buffer:")
					print(dbg)
				}
				response = try parse()
				if debug, let dbg = response {
					print("resp parsed response:")
					print(dbg)
				}
				if inTransaction {
					guard response!.type == .string, let result = response!.content as? String, result == "QUEUED" else {
						throw UniRedisError.error(detail: "unexpected redis response \(response!)")
					}
				}
			} catch ParserError.incomplete {
				// just pass through and try to read more data below
			} catch ParserError.invalid(let at) {
				throw UniRedisError.error(detail: "invalid redis response at '\(at)'")
			}
			if response == nil {
				do {
					let input = try s.recv()
					if debug, let dbg = String(data: input, encoding: .utf8) {
						print("resp raw response:")
						print(dbg)
					}
					inBuffer.append(contentsOf: [UInt8](input))
				} catch UniSocketError.error(let detail) {
					throw UniRedisError.error(detail: "socket error while reading response, \(detail)")
				}
			}
		}
		return response!
	}

}
