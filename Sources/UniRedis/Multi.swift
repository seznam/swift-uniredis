import Foundation

extension UniRedis {

	public func multi(debug: Bool = false, _ closure: () throws -> Void) throws -> UniRedisResponse {
		defer {
			if inTransaction {
				inTransaction = false
				_ = try? cmd("DISCARD", debug: debug)
			}
		}
		let resp = try cmd("MULTI", debug: debug)
		guard resp.type == .string, let result = resp.content as? String, result == "OK" else {
			throw UniRedisError.error(detail: "unexpected redis response \(resp)")
		}
		inTransaction = true
		try closure()
		inTransaction = false
		return try cmd("EXEC", debug: debug)
	}

}
