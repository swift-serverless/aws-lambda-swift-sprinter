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

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}

let logger = Logger(label: "AWS.Lambda.HTTPSRequest")

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

do {
    let sprinter = try SprinterNIO()
    sprinter.register(handler: "getHttps", lambda: lambda)
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
