# RedisDemo

[![Swift 5](https://img.shields.io/badge/Swift-5.0-blue.svg)](https://swift.org/download/) [![Swift 5.1.5](https://img.shields.io/badge/Swift-5.1.5-blue.svg)](https://swift.org/download/)

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework and the plugin [LambdaSwiftSprinterNioPlugin](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin) to build a lambda capable to perform an Redis request using
[RediStack](https://gitlab.com/mordil/swift-redi-stack.git).

## Swift code

Define an Event and a Response as Codable.
```swift
import AsyncHTTPClient
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LambdaSwiftSprinter
import LambdaSwiftSprinterNioPlugin
import Logging
import NIO
import NIOFoundationCompat
import RediStack

struct Event: Codable {
    let key: String
    let value: String
}

struct Response: Codable {
    let value: String
}
```



Add a loger:
```swift
let logger = Logger(label: "AWS.Lambda.Redis")
```

Add a redis connection:
```swift
let elasticacheConfigEndpoint = "redis"

let eventLoop = httpClient.eventLoopGroup.next()
let connection = try? RedisConnection.connect(
        to: try .makeAddressResolvingHost(elasticacheConfigEndpoint,
                                          port: RedisConnection.defaultPort),
        on: eventLoop
    ).wait()



enum LambdaError: Error {
    case redisConnectionFailed
}
```

Define the Lambda:
```swift
let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
    
    guard let connection = connection else {
        throw LambdaError.redisConnectionFailed
    }
    
    let future = connection.set(event.key, to: event.value)
        .flatMap {
            return connection.get(event.key)
        }
        .map { content -> Response in
            return Response(value: content ?? "")
        }
    return future
}
```

If there are not error, the Event will be automatically decoded inside the lambda and then used to perform a `set` and a `get` to Redis.
The value of the `get` is returned into the Response.

Then use this boilerplate code to run the lambda:
```swift
do {
    
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "setGet", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
```

This will initialize the Sprinter with a Sprinter based on NIO 2 library.

Then the internal handler `setGet` is being registered.

Finally the sprinter run.

Any error will be logged.

Note

In this example we used [swift-log](https://github.com/apple/swift-log.git) to log the output.

## Deployment

To build this example make sure the following lines on the `Makefile` are not commented and the other example configurations are commented.

```
...

# HelloWorld Example Configuration
# SWIFT_EXECUTABLE=HelloWorld
# SWIFT_PROJECT_PATH=Examples/HelloWorld
# LAMBDA_FUNCTION_NAME=HelloWorld
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).helloWorld

....

# RedisDemo Example Configuration
SWIFT_EXECUTABLE?=RedisDemo
SWIFT_PROJECT_PATH?=Examples/RedisDemo
LAMBDA_FUNCTION_NAME?=RedisDemo
LAMBDA_HANDLER?=$(SWIFT_EXECUTABLE).setGet

...
```

Then follow the main [README](https://github.com/swift-sprinter/aws-lambda-swift-sprinter) to build and test the code.

## Test

The test event is defined in the file `event.json`
```json
{
    "key": "language",
    "value": "Swift"
}
```

expected response:

```json
{"value":"Swift"}
```

Change it to try different output and error conditions.

# LambdaSwiftSprinter

To know more refer to [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core).
