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

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import LambdaSwiftSprinterNioPlugin
import Logging
import S3
import NIO
import NIOFoundationCompat

struct Bucket: Codable {
    let name: String
    let key: String
}

struct Response: Codable {
    let value: String?
}

let s3 = S3(region: .useast1)

let logger = Logger(label: "AWS.Lambda.S3Test")

let getObject: SyncCodableNIOLambda<Bucket, Response> = { (event, context) throws -> EventLoopFuture<Response> in
    
    let getObjectRequest = S3.GetObjectRequest(bucket: event.name, key: event.key)
    let future = s3.getObject(getObjectRequest)
        .flatMapThrowing { (response) throws -> String in
            guard let body = response.body,
                let value = String(data: body, encoding: .utf8) else {
                return ""
            }
            return value
        }.map { content -> Response in
            return Response(value: content)
        }
    return future
}

//let getObject: AsyncCodableNIOLambda<Bucket, Response> = { event, _, completion in
//
//    let getObjectRequest = S3.GetObjectRequest(bucket: event.name, key: event.key)
//    do {
//        let response = try s3.getObject(getObjectRequest).wait()
//
//        guard let body = response.body else {
//            logger.info("Body is empty")
//            completion(.success(Response(value: "")))
//            return
//        }
//        let value = String(data: body, encoding: .utf8)
//        completion(.success(Response(value: value)))
//    } catch {
//        completion(.failure(error))
//    }
//}

do {
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "getObject", lambda: getObject)
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
