//    Copyright 2019 (c) Andrea Scuderi - https://github.com/swift-sprinter
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

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

enum MyError: Error {
    case invalidParameters
}

let logger = Logger(label: "AWS.Lambda.HTTPSRequest")

/**
 How to use the `SyncCodableNIOLambda<Event, Response>` lambda handler.

 - The code is used by this example.
 - Make sure the handler is registered:
 
 ```
 sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
 ```
*/
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

/**
 How to use the `SyncDictionaryNIOLambda` lambda handler.

 - The code is unused.
 - Make sure the handler is registered.
 - If it's required by the lambda implementation, amend the following lines:
 
 ```
 //sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
 sprinter.register(handler: "getHttps", lambda: syncDictionaryNIOLambda)
 
 ```
*/
let syncDictionaryNIOLambda: SyncDictionaryNIOLambda = { (event, context) throws -> EventLoopFuture<[String: Any]> in

    guard let url = event["url"] as? String else {
        throw MyError.invalidParameters
    }

    let request = try HTTPClient.Request(url: url)
    let future = httpClient.execute(request: request, deadline: nil)
        .flatMapThrowing { (response) throws -> String in
            guard let body = response.body,
                let value = body.getString(at: 0, length: body.readableBytes) else {
                    throw SprinterError.invalidJSON
            }
            return value
        }.map { content -> [String: Any] in
            return ["url": url,
                    "content": content]
        }
    return future
}

/**
 How to use the `AsyncDictionaryNIOLambda` lambda handler.

 - The code is unused.
 - Make sure the handler is registered.
 - If it's required by the lambda implementation, amend the following lines:
 
 ```
 //sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
 sprinter.register(handler: "getHttps", lambda: asynchDictionayNIOLambda)
 
 ```
*/
let asynchDictionayNIOLambda: AsyncDictionaryNIOLambda = { (event, context, completion) -> Void in
    guard let url = event["url"] as? String else {
        completion(.failure(MyError.invalidParameters))
        return
    }
    do {
        let request = try HTTPClient.Request(url: url)
        let dictionary: [String: Any] = try httpClient.execute(request: request, deadline: nil)
            .flatMapThrowing { (response) throws -> String in
                guard let body = response.body,
                    let value = body.getString(at: 0, length: body.readableBytes) else {
                        throw SprinterError.invalidJSON
                }
                return value
        }.map { content -> [String: Any] in
            return ["url": url,
                    "content": content]
        }
        .wait()
        completion(.success(dictionary))
    } catch {
        completion(.failure(error))
    }
}

/**
 How to use the `AsyncCodableNIOLambda<Event, Response>` lambda handler.

 - The code is unused.
 - Make sure the handler is registered.
 - If it's required by the lambda implementation, amend the following lines:
 
 ```
 //sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
 sprinter.register(handler: "getHttps", lambda: asyncCodableNIOLambda)
 
 ```
*/
let asyncCodableNIOLambda: AsyncCodableNIOLambda<Event, Response> = { (event, context, completion) -> Void in
    do {
        let request = try HTTPClient.Request(url: event.url)
        let reponse: Response = try httpClient.execute(request: request, deadline: nil)
            .flatMapThrowing { (response) throws -> String in
                guard let body = response.body,
                    let value = body.getString(at: 0, length: body.readableBytes) else {
                        throw SprinterError.invalidJSON
                }
                return value
        }.map { content -> Response in
            return Response(url: event.url, content: content)
        }
        .wait()
        completion(.success(reponse))
    } catch {
        completion(.failure(error))
    }
}

/**
 Deprecated style of implementing the lambda using the core framework.
 
 - The example has been left to keep the compatibility with the tutorial:
 
 [How to work with aws lambda in swift](https://medium.com/better-programming/how-to-work-with-aws-lambda-in-swift-28326c5cc765)
 
 
 - The code is unused.
 - Make sure the handler is registered.
 - If it's required by the lambda implementation, amend the following lines:
 
 ```
 //sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
 sprinter.register(handler: "getHttps", lambda: lambda)
 
 ```
*/
let lambda: SyncCodableLambda<Event, Response> = { (input, context) throws -> Response in
    
    let request = try HTTPClient.Request(url: input.url)
    let response = try httpClient.execute(request: request, deadline: nil).wait()
    
    guard let body = response.body,
        let data = body.getData(at: 0, length: body.readableBytes) else {
            throw SprinterError.invalidJSON
    }
    let content = String(data: data, encoding: .utf8) ?? ""
    
    return Response(url: input.url, content: content)
}


/// The following code it's required to setup, register, run the lambda and log errors.
do {
    let sprinter = try SprinterNIO()
    //Note amend this line in case if it's required to use a different lambda handler.
    sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
