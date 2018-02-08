import Foundation
import Resolver

extension UniRedis {

	private func lockOwner(_ owner: String? = nil) throws -> String {
		if let own = owner {
			return own
		} else if let host = Resolver.getHostname() {
			return host
		} else {
			throw UniRedisError.error(detail: "Resolver.getHostname() failed")
		}
	}

	public func lockRead(id: String = "lock", owner: String? = nil, expire: UInt = 60, timeout: UInt = 10) throws -> Bool {
		var locked: Bool = false
		let me = try lockOwner(owner)
		let timelimit = UInt(time(nil)) + timeout
		while timelimit >= UInt(time(nil)) {
			let resp = try self.multi {
				_ = try self.cmd("EXISTS", params: [ "\(id).writelock" ])
				_ = try self.cmd("SADD", params: [ "\(id).readlock", me ])
				_ = try self.cmd("EXPIRE", params: [ "\(id).readlock", "\(expire)" ])
			}
			guard resp.type == .array, let array = resp.content as? [UniRedisResponse], let wlock = try array[0].toInt(), wlock == 0 else {
				_ = try self.cmd("SREM", params: [ "\(id).read", me ])
				usleep(100000)
				continue
			}
			locked = true
			break
		}
		return locked
	}

	public func lockReadRefresh(id: String = "lock", owner: String? = nil, expire: UInt = 60) throws -> Void {
		let me = try lockOwner(owner)
		if try self.cmd("SISMEMBER", params: [ "\(id).readlock", me ]).toBool() {
			_ = try self.cmd("EXPIRE", params: [ "\(id).readlock", "\(expire)" ])
		}
	}

	public func unlockRead(id: String = "lock", owner: String? = nil, expire: UInt = 60) throws -> Void {
		let me = try lockOwner(owner)
		_ = try self.multi {
			_ = try self.cmd("SREM", params: [ "\(id).readlock", me ])
			_ = try self.cmd("EXPIRE", params: [ "\(id).readlock", "\(expire)" ])
		}
	}

	public func lockWrite(id: String = "lock", owner: String? = nil, expire: UInt = 60, timeout: UInt = 10) throws -> Bool {
		var locked: Bool = false
		let me = try lockOwner(owner)
		let timelimit = UInt(time(nil)) + timeout
		while timelimit >= UInt(time(nil)) {
			let resp = try self.multi {
				_ = try self.cmd("SET", params: [ "\(id).writelock", me, "NX", "EX", "\(expire)" ])
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

	public func lockWriteRefresh(id: String = "lock", owner: String? = nil, expire: UInt = 60) throws -> Void {
		let me = try lockOwner(owner)
		if let locked = try self.cmd("GET", params: [ "\(id).writelock" ]).toString(), locked == me {
			_ = try self.cmd("EXPIRE", params: [ "\(id).writelock", "\(expire)" ])
		}
	}

	public func unlockWrite(id: String = "lock", owner: String? = nil) throws -> Void {
		let me = try lockOwner(owner)
		if let locked = try self.cmd("GET", params: [ "\(id).writelock" ]).toString(), locked == me {
			_ = try self.cmd("DEL", params: [ "\(id).writelock" ])
		}
	}

}
