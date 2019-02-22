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

	public func pipeline(debug: Bool = false, _ closure: () throws -> Void) throws -> [UniRedisResponse] {
		defer {
			pipelineCount = 0
			if inPipeline {
				inPipeline = false
				outBuffer.removeAll(keepingCapacity: true)
			}
		}
		inPipeline = true
		try closure()
		inPipeline = false
		try sendBuffer()
		inBuffer.removeAll(keepingCapacity: true)
		var response = [UniRedisResponse]()
		while pipelineCount > 0 {
			let resp = try readResponse(debug: debug)
			response.append(resp)
			pipelineCount -= 1
		}
		return response
	}

}
