import Foundation
import UniSocket

extension UniRedis {

	public func lockRead(id: String = "lock", owner: String? = nil, expire: UInt = 60, timeout: UInt = 10) throws -> Bool {
		var locked: Bool = false
		let member: String
		if let string = owner {
			member = string
		} else if let string = UniSocket.gethostname() {
			member = string
		} else {
			throw UniRedisError.error(detail: "gethostname() failed")
		}
		let timelimit = UInt(time(nil)) + timeout
		while timelimit >= UInt(time(nil)) {
			let resp = try self.multi {
				_ = try self.cmd("EXISTS", params: [ "\(id).writelock" ])
				_ = try self.cmd("SADD", params: [ "\(id).readlock", member ])
				_ = try self.cmd("EXPIRE", params: [ "\(id).readlock", "\(expire)" ])
			}
			guard resp.type == .array, let array = resp.content as? [UniRedisResponse], let wlock = try array[0].toInt(), wlock == 0 else {
				_ = try self.cmd("SREM", params: [ "\(id).read", member ])
				usleep(100000)
				continue
			}
			locked = true
			break
		}
		return locked
	}

	public func unlockRead(id: String = "lock", owner: String? = nil, expire: UInt = 60) throws -> Void {
		let member: String
		if let string = owner {
			member = string
		} else if let string = UniSocket.gethostname() {
			member = string
		} else {
			throw UniRedisError.error(detail: "gethostname() failed")
		}
		_ = try self.multi {
			_ = try self.cmd("SREM", params: [ "\(id).readlock", member ])
			_ = try self.cmd("EXPIRE", params: [ "\(id).readlock", "\(expire)" ])
		}
	}

	public func lockWrite(id: String = "lock", owner: String? = nil, expire: UInt = 60, timeout: UInt = 10) throws -> Bool {
		var locked: Bool = false
		let member: String
		if let string = owner {
			member = string
		} else if let string = UniSocket.gethostname() {
			member = string
		} else {
			throw UniRedisError.error(detail: "gethostname() failed")
		}
		let timelimit = UInt(time(nil)) + timeout
		while timelimit >= UInt(time(nil)) {
			let resp = try self.multi {
				_ = try self.cmd("SET", params: [ "\(id).writelock", member, "NX", "EX", "\(expire)" ])
				_ = try self.cmd("EXISTS", params: [ "\(id).readlock" ])
			}
			guard resp.type == .array, let array = resp.content as? [UniRedisResponse], let wlock = try array[0].toString(), wlock == "OK" else {
				usleep(100000)
				continue
			}
			guard let rlock = try array[1].toInt(), rlock == 0 else {
				_ = try self.cmd("DEL", params: [ "\(id).writelock" ])
				usleep(100000)
				continue
			}
			locked = true
			break
		}
		return locked
	}

	public func unlockWrite(id: String = "lock", owner: String? = nil) throws -> Void {
		let member: String
		if let string = owner {
			member = string
		} else if let string = UniSocket.gethostname() {
			member = string
		} else {
			throw UniRedisError.error(detail: "gethostname() failed")
		}
		if let locked = try self.cmd("GET", params: [ "\(id).writelock" ]).toString(), locked == member {
			_ = try self.cmd("DEL", params: [ "\(id).writelock" ])
		}
	}

}
