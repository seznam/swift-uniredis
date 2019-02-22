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
