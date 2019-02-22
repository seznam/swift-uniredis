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

extension UniRedis {

	func getMasterFromSentinel() throws -> (String, Int32) {
		guard sentinel else {
			return (host, port)
		}
		do {
			sock = try UniSocket(type: .tcp, peer: host, port: port, timeout: timeout)
			try sock!.attach()
			let resp = try cmd("SENTINEL", params: [ "MASTERS" ])
			_ = try cmd("QUIT")
			sock = nil
			try resp.throwOnError()
			guard resp.type == .array else {
				throw UniRedisError.error(detail: "unexpected response type '\(resp.type)' from sentinel")
			}
			guard let array = resp.content as? [UniRedisResponse] else {
				throw UniRedisError.error(detail: "failed to parse response from sentinel")
			}
			guard array.count > 0 else {
				throw UniRedisError.error(detail: "empty response from sentinel")
			}
			let first = try array[0].toHash() // TODO: for now assume the sentinel monitors just one cluster
			if let i = first["ip"], let p = first["port"], let pp = Int32(p) {
				return (i, pp)
			}
		} catch UniSocketError.error(let detail) {
			throw UniRedisError.error(detail: "socket error while querying sentinel, \(detail)")
		} catch UniRedisError.error(let detail) {
			throw UniRedisError.error(detail: detail)
		} catch {
			throw UniRedisError.error(detail: "\(error)")
		}
		throw UniRedisError.error(detail: "failed to get master from sentinel")
	}

}
