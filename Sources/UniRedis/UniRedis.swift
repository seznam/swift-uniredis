import Foundation
import Regex
import UniSocket

public enum UniRedisError: Error {
	case error(detail: String)
}

public class UniRedis {

	public let host: String
	public var port: Int32 = 6379
	public var db: Int = 0
	var password: String?
	var timeout: UniSocketTimeout = (connect: 4, read: 4, write: 4)

	var sock: UniSocket?
	var inBuffer = [UInt8]()
	var outBuffer = Data()
	var inTransaction: Bool = false
	var inPipeline: Bool = false
	var pipelineCount: Int = 0

	enum ParserError: Error {
		case incomplete
		case invalid(at: Int)
	}

	public init(_ url: String) throws {
		guard let match = url =~ "^(?:redis://)?(?::([^@]+)@)?([^:/]+)(?::([0-9]+))?(?:/([0-9]+))?$", match.count > 0 else {
			throw UniRedisError.error(detail: "failed to parse redis url '\(url)'")
		}
		host = match[0].groups[1]
		if match[0].groups[2].characters.count > 0 {
			port = Int32(match[0].groups[2])!
		}
		if match[0].groups[3].characters.count > 0 {
			db = Int(match[0].groups[3])!
		}
		if match[0].groups[0].characters.count > 0 {
			password = match[0].groups[0]
		}
	}

	public init(host: String, port: Int32 = 6379, db: Int = 0, password: String? = nil) {
		self.host = host
		self.port = port
		self.db = db
		self.password = password
	}

	public init(_ redis: UniRedis) {
		self.host = redis.host
		self.port = redis.port
		self.db = redis.db
		self.password = redis.password
	}

	public func connect() throws -> Void {
		guard sock == nil else {
			throw UniRedisError.error(detail: "redis already connected")
		}
		do {
			sock = try UniSocket(type: .tcp, peer: host, port: port, timeout: timeout)
			try sock!.attach()
			if let p = password {
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
				let input = try s.recv()
				if debug, let dbg = String(data: input, encoding: .utf8) {
					print("resp raw response:")
					print(dbg)
				}
				inBuffer.append(contentsOf: [UInt8](input))
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
						throw UniRedisError.error(detail: "unexpected redis response \(response)")
					}
				}
			} catch ParserError.incomplete {
				continue
			} catch ParserError.invalid(let at) {
				throw UniRedisError.error(detail: "invalid redis response at '\(at)'")
			} catch UniSocketError.error(let detail) {
				throw UniRedisError.error(detail: "socket error while reading response, \(detail)")
			}
		}
		return response!
	}

}
