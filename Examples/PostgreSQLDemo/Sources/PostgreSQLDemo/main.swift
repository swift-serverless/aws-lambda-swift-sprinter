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
import PostgresNIO

struct Event: Codable {
    let query: String
}

struct Response: Codable {
    let value: String
}

enum LambdaError: Error {
    case connectionFailed
}

let logger = Logger(label: "AWS.Lambda.Redis")
let endpoint = "<yourdb>.rds.amazonaws.com"
do {
    let eventLoop = httpClient.eventLoopGroup.next()
    let connection = try PostgresConnection.connect(
        to: try .makeAddressResolvingHost(endpoint,
                                          port: 5432),
        on: eventLoop
    ).wait()
    
    logger.error("after connection")
    
    try connection.authenticate(username: "<username>",
                                database: "<db>",
                                password: "<password>").wait()
    
    
    let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
        
        let future = connection.query(event.query).map { (rows) -> Response in
            return Response(value: "\(rows)")
            
        }
        return future
    }
    
    
    let sprinter = try SprinterNIO()
    //Note amend this line in case if it's required to use a different lambda handler.
    sprinter.register(handler: "query", lambda: syncCodableNIOLambda)
    
    try sprinter.run()
} catch {
    logger.error("\(String(describing: error))")
}
