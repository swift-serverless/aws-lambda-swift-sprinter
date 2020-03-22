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
import RediStack

struct Event: Codable {
    let key: String
    let value: String
}

struct Response: Codable {
    let value: String
}

enum LambdaError: Error {
    case redisConnectionFailed
}

let logger = Logger(label: "AWS.Lambda.Redis")

//Change this with your redis endpoint
let elasticacheConfigEndpoint = "redis"

let eventLoop = httpClient.eventLoopGroup.next()
let connection = try? RedisConnection.connect(
        to: try .makeAddressResolvingHost(elasticacheConfigEndpoint,
                                          port: RedisConnection.defaultPort),
        on: eventLoop
    ).wait()


let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
    
    guard let connection = connection,
        let key = RedisKey(rawValue: event.key)  else {
        throw LambdaError.redisConnectionFailed
    }
    
    let future = connection.set(key, to: event.value)
        .flatMap { _ in
            return connection.get(key)
        }
        .map { content -> Response in
            return Response(value: content ?? "")
        }
    return future
}

do {
    
    let sprinter = try SprinterNIO()
    //Note amend this line in case if it's required to use a different lambda handler.
    sprinter.register(handler: "setGet", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
