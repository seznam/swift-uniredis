![](https://img.shields.io/badge/Swift-4.2-orange.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)
![Build Status](https://travis-ci.com/seznam/swift-uniredis.svg?branch=master)

# UniRedis

Redis client for Swift which supports authentication, transactions, pipelining
and sentinel. It also provides own implementation of ro/rw locks to synchronize
multiple clients accessing data in redis storage.

## Usage

Connect to redis on localhost, set and get simple value:

```swift
import UniRedis

let key = "test"
let value = Date().timeIntervalSince1970

do {
	let redis = try UniRedis("redis://localhost:6379")
	try redis.connect()
	try redis.cmd("SETEX", params: [ key, "60", "\(value)" ])
	let result = try redis.cmd("GET", params: [ key ]).toInt()
	print("key '\(key)' has value \(result)")
	redis.disconnect()
} catch UniRedisError.error(let detail) {
	print(detail)
}
```

Connect to remote redis server using non-default timeout values and perform a
transaction in non-default database:

```swift
import UniRedis
import UniSocket // https://github.com/seznam/swift-unisocket

let host = "redis.seznam.net"
let port = 6379

do {
	let redis = try UniRedis(host: host, port: port, db: 2)
	redis.timeout = (connect: 3, read: 2, write: 1)
	try redis.connect()
	let response = try redis.multi {
		_ = try redis.cmd("HMSET", params: [ "connection", "host", host, "port", "\(port)" ])
		_ = try redis.cmd("HGET", params: [ "connection", "host" ]).toString()
		_ = try redis.cmd("DEL", params: [ "connection" ])
	}
	guard response.type == .array, let result = response.content as? [UniRedisResponse], result.count == 3 else {
		throw UniRedisError.error(detail: "redis transaction failed, unexpected response")
	}
	if let value = try result[1].toString(), host == value {
		print("match")
	} else {
		print("mismatch")
	}
	redis.disconnect()
} catch UniRedisError.error(let detail) {
	print(detail)
}
```

Connect to local username and password protected redis storage and update lock-protected
content in database 10:

```swift
import UniRedis

let username = "optionalUsername"
let password = "RedisRequirePassword"

do {
	let redis = try UniRedis("redis://\(username):\(password)@localhost/10")
	// or let redis = try UniRedis("redis://\(password)@localhost/10")
	try redis.connect()
	guard try redis.lockWrite(expire: 5, timeout: 5) else {
		throw UniRedisError.error(detail: "failed to get write lock")
	}
	if let value = try redis.cmd("LPOP", params: [ "queue" ]).toString() {
		_ = try redis.cmd("SETEX", params: [ value, "5", "\(Date().timeIntervalSince1970)" ])
	}
	try? redis.unlockWrite()
	redis.disconnect()
} catch UniRedisError.error(let detail) {
	print(detail)
}
```

Connect to a sentinel-controlled redis cluster:

```swift
import UniRedis

let hostname = "sentinel.host.seznam.net"

do {
	let redis = try UniRedis("redis+sentinel://\(hostname)")
	try redis.connect()
	let response = try redis.cmd("ROLE")
	guard response.type == .array, let result = response.content as? [UniRedisResponse], result.count == 3 else {
		throw UniRedisError.error(detail: "unexpected role response")
	}
	if let value = try result[0].toString(), value == "master" {
		print("good, connected to master")
	} else {
		print("something went wrong, not connected to master")
	}
	redis.disconnect()
} catch UniRedisError.error(let detail) {
	print(detail)
}
```

Utilize messaging capabilities of redis:

```swift
import UniRedis

do {
	let channel = "news"
	let client1 = try UniRedis("redis://localhost")
	let client2 = try UniRedis("redis://localhost")
	try client1.connect()
	try client2.connect()
	try client1.subscribe(channel: [ channel ])
	try client2.publish(channel: channel, message: "weather report")
	if let message = try client1.msg() {
		print("got message '\(message.message)' on channel '\(message.channel)'")
	}
	try client1.unsubscribe(channel: [ channel ])
	client1.disconnect()
	client2.disconnect()
} catch UniRedisError.error(let detail) {
	print(detail)
} catch {
	print("unexpected exception")
}
```

## Credits

Written by [Daniel Bilik](https://github.com/ddbilik/), copyright [Seznam.cz](https://onas.seznam.cz/en/), licensed under the terms of the Apache License 2.0.
