/*
 * Copyright 2019 Seznam.cz, a.s.
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

public typealias UniRedisMessage = (channel: String, pattern: String?, message: String)

extension UniRedis {

	public func subscribe(channel: [String] = [], pattern: [String] = []) throws -> Void {
		for ch in channel {
			let resp = try cmd("SUBSCRIBE", params: [ ch ])
			guard resp.type == .array, let mresp = resp.content as? [UniRedisResponse], mresp.count == 3 else {
				throw UniRedisError.error(detail: "unexpected redis response \(resp)")
			}
			guard let r = try mresp[0].toString(), r == "subscribe", let c = try mresp[1].toString(), c == ch else {
				throw UniRedisError.error(detail: "unexpected subcribe response")
			}
			subscribedChannel.insert(ch)
		}
		for p in pattern {
			let resp = try cmd("PSUBSCRIBE", params: [ p ])
			guard resp.type == .array, let mresp = resp.content as? [UniRedisResponse], mresp.count == 3 else {
				throw UniRedisError.error(detail: "unexpected redis response \(resp)")
			}
			guard let r = try mresp[0].toString(), r == "psubscribe", let c = try mresp[1].toString(), c == p else {
				throw UniRedisError.error(detail: "unexpected psubcribe response")
			}
			subscribedPattern.insert(p)
		}
	}

	public func unsubscribe(channel: [String] = [], pattern: [String] = []) throws -> Void {
		for ch in channel {
			guard subscribedChannel.contains(ch) else {
				continue
			}
			let resp = try cmd("UNSUBSCRIBE", params: [ ch ])
			guard resp.type == .array, let mresp = resp.content as? [UniRedisResponse], mresp.count == 3 else {
				throw UniRedisError.error(detail: "unexpected redis response \(resp)")
			}
			guard let r1 = try mresp[0].toString(), r1 == "unsubscribe", let r2 = try mresp[1].toString(), r2 == ch else {
				throw UniRedisError.error(detail: "unexpected unsubcribe response")
			}
			subscribedChannel.remove(ch)
		}
		for p in pattern {
			guard subscribedPattern.contains(p) else {
				continue
			}
			let resp = try cmd("PUNSUBSCRIBE", params: [ p ])
			guard resp.type == .array, let mresp = resp.content as? [UniRedisResponse], mresp.count == 3 else {
				throw UniRedisError.error(detail: "unexpected redis response \(resp)")
			}
			guard let r1 = try mresp[0].toString(), r1 == "punsubscribe", let r2 = try mresp[1].toString(), r2 == p else {
				throw UniRedisError.error(detail: "unexpected punsubcribe response")
			}
			subscribedPattern.remove(p)
		}
	}

	public func publish(channel: String, message: String) throws -> Void {
		_ = try cmd("PUBLISH", params: [ channel, message ]).toInt()
	}

	public func msg(debug: Bool = false) throws -> UniRedisMessage? {
		var message: UniRedisMessage? = nil
		let from = Date().timeIntervalSince1970
		do {
			let resp = try readResponse(debug: debug)
			guard resp.type == .array, let mresp = resp.content as? [UniRedisResponse] else {
				throw UniRedisError.error(detail: "unexpected redis response \(resp)")
			}
			guard let r0 = try mresp[0].toString(), (r0 == "message" &&  mresp.count == 3) || (r0 == "pmessage" && mresp.count == 4) else {
				throw UniRedisError.error(detail: "unexpected redis response - expected message or pmessage")
			}
			switch r0 {
			case "pmessage":
				if let r1 = try mresp[1].toString(), let r2 = try mresp[2].toString(), let r3 = try mresp[3].toString() {
					message = UniRedisMessage(channel: r2, pattern: r1, message: r3)
				}
			default:
				if let r1 = try mresp[1].toString(), let r2 = try mresp[2].toString() {
					message = UniRedisMessage(channel: r1, pattern: nil, message: r2)
				}
			}
		} catch UniSocketError.error(let detail) {
			// NOTE: sort-of hack, detect read timeout by measuring delay and throw only on other socket errors
			let to = Date().timeIntervalSince1970
			if UInt(to - from) < sock!.timeout.read {
				throw UniRedisError.error(detail: "failed to receive message, \(detail)")
			}
		}
		return message
	}

}
