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
import LambdaSwiftSprinter

struct Event: Codable {
    let name: String
}

struct Response: Codable {
    let message: String
}

enum MyLambdaError: Error {
    case invalidEvent
}

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

public func log(_ object: Any, flush: Bool = false) {
    fputs("\(object)\n", stderr)
    if flush {
        fflush(stderr)
    }
}

do {
    let sprinter = try SprinterCURL()
    sprinter.register(handler: "helloWorld", lambda: syncLambda)
//    sprinter.register(handler: "helloWorld2", lambda: syncDictLambda)
//    sprinter.register(handler: "helloWorld3", lambda: asyncLambda)
//    sprinter.register(handler: "helloWorld4", lambda: asyncDictLambda)
    try sprinter.run()
} catch {
    log(String(describing: error))
}
