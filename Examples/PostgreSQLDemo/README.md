# PostgreSQLDemo

[![Swift 5](https://img.shields.io/badge/Swift-5.0-blue.svg)](https://swift.org/download/) [![Swift 5.1.4](https://img.shields.io/badge/Swift-5.1.4-blue.svg)](https://swift.org/download/)

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework and the plugin [LambdaSwiftSprinterNioPlugin](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin) to build a lambda capable to perform an Postgres query using
[PostgresNIO](https://github.com/vapor/postgres-nio.git).

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
import PostgresNIO

struct Event: Codable {
    let query: String
}

struct Response: Codable {
    let value: String
}
```



Add a loger:
```swift
let logger = Logger(label: "AWS.Lambda.Postgres")
```

Add a redis connection, define the Lambda and run it:
```swift
enum LambdaError: Error {
    case connectionFailed
}

//let endpoint = "<yourdb>.rds.amazonaws.com"
let endpoint = "postgres"

do {
    let eventLoop = httpClient.eventLoopGroup.next()
    let connection = try PostgresConnection.connect(
        to: try .makeAddressResolvingHost(endpoint,
                                          port: 5432),
        on: eventLoop
    ).wait()
    
    logger.error("after connection")
    
    try connection.authenticate(username: "username1",
                                database: "demoDB",
                                password: "password1").wait()
    
    
    let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
        
        let future = connection.query(event.query).map { (rows) -> Response in
            return Response(value: "\(rows)")
            
        }
        return future
    }
    
    
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "query", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
```

If there are not error, the Event will be automatically decoded inside the lambda and then used to perform a `query` to Postgres.
The result of the `query` is returned into the Response.


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

# PostgreSQLDemo Example Configuration
SWIFT_EXECUTABLE=PostgreSQLDemo
SWIFT_PROJECT_PATH=Examples/PostgreSQLDemo
LAMBDA_FUNCTION_NAME=PostgreSQLDemo
LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).query

...
```

Then follow the main [README](https://github.com/swift-sprinter/aws-lambda-swift-sprinter) to build and test the code.

## Test

The test event is defined in the file `event.json`
```json
{
    "query": "SELECT 1+1 as result;"
}
```

expected response:

```json
{"value":"[[\"result\": 2]]"}
```

Change it to try different output and error conditions.

# LambdaSwiftSprinter

To know more refer to [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core).
