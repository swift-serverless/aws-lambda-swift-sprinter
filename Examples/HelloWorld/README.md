# HelloWorld

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework to build a simple lambda.

## Swift code

Define an Event and a Response as Codable.
```swift
import Foundation
import LambdaSwiftSprinter

struct Event: Codable {
    let name: String
}

struct Response: Codable {
    let message: String
}
```

Define the lambda code:
```swift
let syncLambda: SyncCodableLambda<Event, Response> = { (event, context) throws -> Response in
    let message = "Hello World! Hello \(event.name)!"
    return Response(message: message)
}
```

If there are not error the Event will be automatically decoded inside the syncLambda and then used to return the Response.
This lambda is synchronous, meaning that all the operation are performed on the same lambda thread.

add a log function:
```swift
public func log(_ object: Any, flush: Bool = false) {
    fputs("\(object)\n", stderr)
    if flush {
        fflush(stderr)
    }
}
```

Then use this boilerplate code to run the lambda:
```swift
do {
    let sprinter = try SprinterCURL()
    sprinter.register(handler: "helloWorld", lambda: syncLambda)
    try sprinter.run()
} catch {
    log(String(describing: error))
}
```

This will initialize the Sprinter with a Sprinter based on CURL library.

Then the internal handler `helloWorld` is being registered.

Finally the sprinter run.

Any error will be logged.

## Deployment

To build this example make sure the following lines on the `Makefile` are not commented and the other example configurations are commented.

```
...

# HelloWorld Example Configuration
SWIFT_EXECUTABLE=HelloWorld
SWIFT_PROJECT_PATH=Examples/HelloWorld
LAMBDA_FUNCTION_NAME=HelloWorld
LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).helloWorld

# HTTPSRequest Example Configuration
# SWIFT_EXECUTABLE=HTTPSRequest
# SWIFT_PROJECT_PATH=Examples/HTTPSRequest
# LAMBDA_FUNCTION_NAME=HTTPSRequest
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getHttps

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
    "name": "Swift-Sprinter"
}
```

Change it to try different output and error conditions.

## Lambda code style

The following code shows different coding styles:
- Synchronous/Asynchronous
- Codable/Dcitionary

```swift
let syncLambda: SyncCodableLambda<Event, Response> = { (event, context) throws -> Response in
    let message = "Hello World! Hello \(event.name)!"
    return Response(message: message)
}

let asyncLambda: AsyncCodableLambda<Event, Response> = { event, _, completion in
    let message = "Hello World! Hello \(event.name)!"
    return completion(.success(Response(message: message)))
}

let syncDictLambda = { (dictionary: [String: Any], context: Context) throws -> [String: Any] in
    var result = [String: Any]()
    if let name = dictionary["name"] as? String {
        let message = "Hello World! Hello \(name)!"
        result["message"] = message
    } else {
        throw MyLambdaError.invalidEvent
    }
    return result
}

let asyncDictLambda: AsyncDictionaryLambda = { dictionary, _, completion in
    var result = [String: Any]()
    if let name = dictionary["name"] as? String {
        let message = "Hello World! Hello \(name)!"
        result["message"] = message
    } else {
        completion(.failure(MyLambdaError.invalidEvent))
    }
    completion(.success(result))
}
```

To know more refer to [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core).