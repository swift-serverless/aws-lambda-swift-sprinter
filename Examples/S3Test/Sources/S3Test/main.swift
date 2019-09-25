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
#if swift(>=5.1) && os(Linux)
    import FoundationNetworking
#endif
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

let s3 = S3(region: .euwest1)

let logger = Logger(label: "AWS.Lambda.S3Test")

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

do {
    let sprinter = try SprinterCURL()
    sprinter.register(handler: "getObject", lambda: getObject)
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}