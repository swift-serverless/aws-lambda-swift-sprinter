# HTTPSRequest

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework and the plugin [LambdaSwiftSprinterNioPlugin](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin) to build a lambda capable to perform an HTTPS request.

## Swift code

Define an Event and a Response as Codable.
```swift
import AsyncHTTPClient
import Foundation
import LambdaSwiftSprinter
import LambdaSwiftSprinterNioPlugin
import Logging

struct Event: Codable {
    let url: String
}

struct Response: Codable {
    let url: String
    let content: String
}
```

Use this code to allow the conversion of a `ByteBuffer` to `Data`
```swift
extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}
```

Add a loger:
```swift
let logger = Logger(label: "AWS.Lambda.HTTPSRequest")
```

Define the lambda:
```swift
let lambda: SyncCodableLambda<Event, Response> = { (input, context) throws -> Response in

    let request = try HTTPClient.Request(url: input.url)
    let response = try httpClient.execute(request: request).wait()

    guard let body = response.body,
        let buffer = body.getBytes(at: 0, length: body.readableBytes) else {
        throw SprinterError.invalidJSON
    }
    let data = Data(buffer)
    let content = String(data: data, encoding: .utf8) ?? ""

    return Response(url: input.url, content: content)
}
```

If there are not error, the Event will be automatically decoded inside the lambda and then used to perform a https request to the url received.
The response of the https request is returned into the Response.
This lambda is synchronous, meaning that all the operation are performed on the same lambda thread.

Then use this boilerplate code to run the lambda:
```swift
do {
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "getHttps", lambda: lambda)
    try sprinter.run()
} catch {
    logger.error(String(describing: error))
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
