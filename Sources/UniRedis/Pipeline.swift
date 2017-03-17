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
