# HTTPSRequest

[![Swift 5](https://img.shields.io/badge/Swift-5.0-blue.svg)](https://swift.org/download/) [![Swift 5.1.4](https://img.shields.io/badge/Swift-5.1.4-blue.svg)](https://swift.org/download/)

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework and the plugin [LambdaSwiftSprinterNioPlugin](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin) to build a lambda capable to perform an HTTPS request.

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

struct Event: Codable {
    let url: String
}

struct Response: Codable {
    let url: String
    let content: String
}
```

Add a loger:
```swift
let logger = Logger(label: "AWS.Lambda.HTTPSRequest")
```

Define the lambda:
```swift
let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
    
    let request = try HTTPClient.Request(url: event.url)
    let future = httpClient.execute(request: request, deadline: nil)
        .flatMapThrowing { (response) throws -> String in
                guard let body = response.body,
                    let value = body.getString(at: 0, length: body.readableBytes) else {
                        throw SprinterError.invalidJSON
            }
            return value
        }.map { content -> Response in
            return Response(url: event.url, content: content)
        }
    return future
}
```

If there are not error, the Event will be automatically decoded inside the lambda and then used to perform a https request to the url received.
The response of the https request is returned into the Response.
This lambda is synchronous, meaning that all the operation are performed on the same lambda thread.

Then use this boilerplate code to run the lambda:
```swift
do {
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
```

This will initialize the Sprinter with a Sprinter based on NIO 2 library.

Then the internal handler `getHttps` is being registered.

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

# HTTPSRequest Example Configuration
SWIFT_EXECUTABLE=HTTPSRequest
SWIFT_PROJECT_PATH=Examples/HTTPSRequest
LAMBDA_FUNCTION_NAME=HTTPSRequest
LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getHttps

# S3Test Example Configuration
# SWIFT_EXECUTABLE=S3Test
# SWIFT_PROJECT_PATH=Examples/S3Test
# LAMBDA_FUNCTION_NAME=S3Test
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getObject

...
```

Then follow the main [README](https://github.com/swift-sprinter/aws-lambda-swift-sprinter) to build and test the code.

## Test

The test event is defined in the file `event.json`
```json
{
    "url": "https://swift.org"
}
```

expected response:

```json
{
    "url": "https://swift.org",
    "content": "<THE HTML PAGE FROM swift.org>"
}
```

Change it to try different output and error conditions.

# LambdaSwiftSprinter

To know more refer to [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core).
