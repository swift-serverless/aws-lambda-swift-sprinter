# S3Test

[![Swift 5](https://img.shields.io/badge/Swift-5.0-blue.svg)](https://swift.org/download/) [![Swift 5.1](https://img.shields.io/badge/Swift-5.1-blue.svg)](https://swift.org/download/) 

This example shows the usage of the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework with the third-party library [https://github.com/swift-aws/aws-sdk-swift.git](https://github.com/swift-aws/aws-sdk-swift.git) to build a lambda capable to perform an HTTPS request to an S3 Bucket.

## Requirements

To launch this code you need:
- to configure an S3 Bucket with public access. From now on we indicate it with: `my-s3-bucket`
- to add a policy to the lambda execution role to allow rw on the S3 Bucket.
- to upload the file `hello.txt` to your S3 Bucket.
- to configure the `event.json` with your S3 Bucket.

## Swift code

Define an Event and a Response as Codable.
```swift
import Foundation
import LambdaSwiftSprinter
import Logging
import S3

struct Bucket: Codable {
    let name: String
    let key: String
}

struct Response: Codable {
    let value: String?
}
```

Change the region with the region of your S3 bucket.

```swift
let s3 = S3(region: .euwest1)
```

add a logger:
```swift
let logger = Logger(label: "AWS.Lambda.HTTPSRequest")
```

define the lambda:
```swift
let getObject: AsyncCodableLambda<Bucket, Response> = { event, _, completion in

    let getObjectRequest = S3.GetObjectRequest(bucket: event.name, key: event.key)
    do {
        let response = try s3.getObject(getObjectRequest).wait()

        guard let body = response.body else {
            logger.info("Body is empty")
            completion(.success(Response(value: "")))
            return
        }
        let value = String(data: body, encoding: .utf8)
        completion(.success(Response(value: value)))
    } catch {
        completion(.failure(error))
    }
}
```

If there are not error, the Event will be automatically decoded inside the lambda and then used to perform the s3.getObject.
The response contains the contente of the file hello.txt stored on your S3 bucket.
This lambda is synchronous, meaning that all the operation are performed on the same lambda thread.

Then use this boilerplate code to run the lambda:
```swift
do {
    let sprinter = try SprinterCURL()
    sprinter.register(handler: "getObject", lambda: getObject)
    try sprinter.run()
} catch {
    logger.error("error: \(error)")
}

```

This will initialize the Sprinter with a Sprinter based on NIO 2 library.

Then the internal handler `getObject` is being registered.

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
# SWIFT_EXECUTABLE=HTTPSRequest
# SWIFT_PROJECT_PATH=Examples/HTTPSRequest
# LAMBDA_FUNCTION_NAME=HTTPSRequest
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getHttps

# S3Test Example Configuration
SWIFT_EXECUTABLE=S3Test
SWIFT_PROJECT_PATH=Examples/S3Test
LAMBDA_FUNCTION_NAME=S3Test
LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getObject

...
```

Then follow the main [README](https://github.com/swift-sprinter/aws-lambda-swift-sprinter) to build and test the code, but after the lambda creation add the policy to the lambda execution role:


```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1494965873000",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::my-s3-bucket",
                "arn:aws:s3:::my-s3-bucket/*"
            ]
        }
    ]
}
```

Note
Change my-s3-bucket with your bucket name

## Test

The test event is defined in the file `event.json`, it's required to edit it and add your S3 Bucket:
```json
{
    "name": "my-s3-bucket",
    "key": "hello.txt"
}
```

expected response:

```json
{"value":"Hello World!"}
```

Change it to try different output and error conditions.

## LambdaSwiftSprinter

To know more refer to [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core).

