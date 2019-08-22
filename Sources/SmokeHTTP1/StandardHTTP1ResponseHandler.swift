// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// StandardHTTP1Response.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import Logging
import SmokeOperations

/**
 Standard implementation of the HttpResponseHandler protocol to
 send the response to a HTTP request.
*/
struct StandardHTTP1ResponseHandler: HTTP1ResponseHandler {
    let requestHead: HTTPRequestHead
    let keepAliveStatus: KeepAliveStatus
    let context: ChannelHandlerContext
    let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
    
    func executeInEventLoop(invocationContext: SmokeServerInvocationContext, execute: @escaping () -> ()) {
        // if we are currently on a thread that can complete the response
        if context.eventLoop.inEventLoop {
            execute()
        } else {
            // otherwise execute on a thread that can
            context.eventLoop.execute {
                execute()
            }
        }
    }
    
    func complete(invocationContext: SmokeServerInvocationContext, status: HTTPResponseStatus,
                  responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        
        invocationContext.invocationReporting.logger.info("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    func completeInEventLoop(invocationContext: SmokeServerInvocationContext, status: HTTPResponseStatus,
                             responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    func completeSilently(invocationContext: SmokeServerInvocationContext, status: HTTPResponseStatus,
                          responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        
        invocationContext.invocationReporting.logger.debug("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    func completeSilentlyInEventLoop(invocationContext: SmokeServerInvocationContext, status: HTTPResponseStatus,
                                     responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.completeSilently(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    private func handleComplete(invocationContext: SmokeServerInvocationContext, status: HTTPResponseStatus,
                                responseComponents: HTTP1ServerResponseComponents) -> Int {
        var headers = HTTPHeaders()
        
        let buffer: ByteBuffer?
        let bodySize: Int
        
        // if there is a body
        if let body = responseComponents.body {
            let data = body.data
            // create a buffer for the body and copy the body into it
            var newBuffer = context.channel.allocator.buffer(capacity: data.count)
            newBuffer.writeBytes(data)
            
            buffer = newBuffer
            bodySize = data.count
            
            // add the content type header
            headers.add(name: HTTP1Headers.contentType, value: body.contentType)
        } else {
            buffer = nil
            bodySize = 0
        }
        
        // add the content length header and write the response head to the response
        headers.add(name: HTTP1Headers.contentLength, value: "\(bodySize)")
        
        // add any additional headers
        responseComponents.additionalHeaders.forEach { header in
            headers.add(name: header.0, value: header.1)
        }
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: requestHead.version,
                                                              status: status,
                                                              headers: headers))), promise: nil)
        
        // if there is a body, write it to the response
        if let buffer = buffer {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        
        let promise: EventLoopPromise<Void>? = self.keepAliveStatus.state ? nil : context.eventLoop.makePromise()
        if let promise = promise {
            let currentContext = context
            // if keep alive is false, close the channel when the response end
            // has been written
            promise.futureResult.whenComplete { _ in
                currentContext.close(promise: nil)
            }
        }
        
        // write the response end and flush
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                          promise: promise)
        
        return bodySize
    }
}
