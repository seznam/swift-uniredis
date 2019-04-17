import XCTest

@testable import UniRedis
import UniSocket

class UniRedisTests: XCTestCase {

	static var allTests = [
		("testRefused", testRefused),
		("testTimeout", testTimeout),
		("testString", testString),
		("testList", testList),
		("testSet", testSet),
		("testHash", testHash),
		("testSortedSet", testSortedSet),
		("testPubSub", testPubSub),
		("testMulti", testMulti),
		("testPipeline", testPipeline),
		("testReadLock", testReadLock),
		("testWriteLock", testWriteLock)
	]

	func testRefused() {
		var exception: String? = nil
		do {
			let redis = try UniRedis("redis://localhost:9")
			try redis.connect()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
			exception = detail
		} catch {
			print("unexpected error")
		}
		XCTAssert(exception != nil && exception!.hasPrefix("socket error while sending") && exception!.hasSuffix("refused"))
	}

	func testTimeout() {
		var exception: String? = nil
		let t: UInt = 2
		let from = Date().timeIntervalSince1970
		do {
			let redis = try UniRedis("redis://169.254.250.250")
			redis.timeout = (connect: t, read: t, write: t)
			try redis.connect()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
			exception = detail
		} catch {
			print("unexpected error")
		}
		let to = Date().timeIntervalSince1970
		let duration = to - from
		XCTAssert(exception != nil && exception!.hasPrefix("socket error while connecting") && duration >= Double(t) && duration < Double(t + 1))
	}

	func testString() {
		var result: String? = nil
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift string"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			_ = try redis.cmd("SETEX", params: [ key, "3", db ])
			result = try redis.cmd("GET", params: [ key ]).toString()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected error")
		}
		XCTAssert(result != nil && result! == db)
	}

	func testList() {
		var result1: String? = nil
		var result2: String? = nil
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			_ = try redis.cmd("RPUSH", params: [ "swift list 1", "first", "second", "third" ])
			result1 = try redis.cmd("RPOPLPUSH", params: [ "swift list 1", "swift list 2" ]).toString()
			result2 = try redis.cmd("LPOP", params: [ "swift list 2" ]).toString()
			_ = try redis.cmd("DEL", params: [ "swift list 1", "swift list 2" ])
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected error")
		}
		XCTAssert(result1 != nil && result2 != nil && result1! == result2!)
	}

	func testSet() {
		var count: UInt? = 0
		var ttl: Int? = 0
		var hit: Bool = false
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift set"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			_ = try redis.cmd("SADD", params: [ key, "one", "two", "three" ])
			ttl = try redis.cmd("TTL", params: [ key ]).toInt()
			count = try redis.cmd("SCARD", params: [ key ]).toUInt()
			hit = try redis.cmd("SISMEMBER", params: [ key, "two" ]).toBool()
			_ = try redis.cmd("DEL", params: [ key ])
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected error")
		}
		XCTAssert(count! == 3 && ttl! == -1 && hit)
	}

	func testHash() {
		var count: UInt? = 0
		var ttl: Int? = 0
		var hit: Bool = true
		var content: [String: String] = [:]
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift hash"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			_ = try redis.cmd("HMSET", params: [ key, "klíč 1", "one", "klíč 2", "two", "klíč 3", "three" ])
			_ = try redis.cmd("EXPIRE", params: [ key, "5" ])
			count = try redis.cmd("HLEN", params: [ key ]).toUInt()
			ttl = try redis.cmd("TTL", params: [ key ]).toInt()
			hit = try redis.cmd("HEXISTS", params: [ key, "nonexistent" ]).toBool()
			content = try redis.cmd("HGETALL", params: [ key ]).toHash()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected error")
		}
		XCTAssert(count! == 3 && ttl! > 0 && !hit && content["klíč 1"] == "one")
	}

	func testSortedSet() {
		var count: UInt? = 0
		var ttl: Int? = 0
		var score: Double? = 0
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift sset"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			_ = try redis.cmd("ZADD", params: [ key, "-1.65", "one", "2.22", "two", "0.111", "three" ])
			_ = try redis.cmd("EXPIRE", params: [ key, "6" ])
			ttl = try redis.cmd("TTL", params: [ key ]).toInt()
			count = try redis.cmd("ZCOUNT", params: [ key, "0", "inf" ]).toUInt()
			score = try redis.cmd("ZSCORE", params: [ key, "one" ]).toDouble()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(count! == 2 && ttl! > 4 && score! < -1.6)
	}

	func testPubSub() {
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let channel = "swift test channel"
		let publishedMessage = "swift test message"
		var receivedMessage: UniRedisMessage? = nil
		do {
			let client1 = try UniRedis("redis://localhost/\(db)")
			let client2 = try UniRedis("redis://localhost/\(db)")
			try client1.connect()
			try client2.connect()
			try client1.subscribe(channel: [ channel ])
			try client2.publish(channel: channel, message: publishedMessage)
			receivedMessage = try client1.msg()
			try client1.unsubscribe(channel: [ channel ])
			client1.disconnect()
			client2.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(receivedMessage != nil && receivedMessage!.message == publishedMessage)
	}

	func testMulti() {
		var value: UInt? = nil
		var hit: Bool = false
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift multi"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			let response = try redis.multi {
				_ = try redis.cmd("SETEX", params: [ key, "1", "5" ])
				_ = try redis.cmd("INCR", params: [ key ])
				_ = try redis.cmd("GET", params: [ key ])
			}
			guard response.type == .array, let result = response.content as? [UniRedisResponse], result.count == 3 else {
				throw UniRedisError.error(detail: "unexpected response")
			}
			value = try result[2].toUInt()
			sleep(2)
			hit = try redis.cmd("EXISTS", params: [ "swift multi" ]).toBool()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(!hit && value! == 6)
	}

	func testPipeline() {
		var value1: UInt? = nil
		var value2: UInt? = nil
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		let key = "swift pipeline"
		do {
			let redis = try UniRedis("redis://localhost/\(db)")
			try redis.connect()
			let result = try redis.pipeline {
				_ = try redis.cmd("SET", params: [ key, "3" ])
				_ = try redis.cmd("INCR", params: [ key ])
				_ = try redis.cmd("GET", params: [ key ])
				_ = try redis.cmd("INCR", params: [ key ])
				_ = try redis.cmd("GET", params: [ key ])
				_ = try redis.cmd("DEL", params: [ key ])
			}
			guard result.count == 6 else {
				throw UniRedisError.error(detail: "unexpected response")
			}
			value1 = try result[2].toUInt()
			value2 = try result[4].toUInt()
			redis.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(value1! == 4 && value2! == 5)
	}

	func testReadLock() {
		var lock1: Bool = false
		var lock2: Bool = false
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		do {
			let client1 = try UniRedis("redis://localhost/\(db)")
			let client2 = try UniRedis("redis://localhost/\(db)")
			try client1.connect()
			try client2.connect()
			guard try client1.lockRead(id: "swift read lock", expire: 3, timeout: 2) else {
				throw UniRedisError.error(detail: "failed to get read lock")
			}
			lock1 = true
			guard try client2.lockRead(id: "swift read lock", expire: 3, timeout: 2) else {
				throw UniRedisError.error(detail: "failed to get read lock")
			}
			lock2 = true
			client1.disconnect()
			client2.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(lock1 && lock2)
	}

	func testWriteLock() {
		var lock1: Bool = false
		var lock2: Bool = false
		let db: String = "\(Int(Date().timeIntervalSince1970) % 15)"
		do {
			let client1 = try UniRedis("redis://localhost/\(db)")
			let client2 = try UniRedis("redis://localhost/\(db)")
			try client1.connect()
			try client2.connect()
			guard try client1.lockWrite(id: "swift write lock", expire: 3, timeout: 2) else {
				throw UniRedisError.error(detail: "failed to get write lock")
			}
			lock1 = true
			guard try client2.lockRead(id: "swift write lock", expire: 3, timeout: 2) else {
				throw UniRedisError.error(detail: "failed to get write lock")
			}
			lock2 = true
			client1.disconnect()
			client2.disconnect()
		} catch UniRedisError.error(let detail) {
			print(detail)
		} catch {
			print("unexpected exception")
		}
		XCTAssert(lock1 && !lock2)
	}

}
