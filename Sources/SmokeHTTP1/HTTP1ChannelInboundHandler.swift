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
// HTTP1ChannelInboundHandler.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import SmokeOperations
import Logging

private func createNewLogger() -> Logger {
    let internalRequestId = UUID().uuidString
    var logger = Logger(label: "com.amazon.SmokeFramework.request.\(internalRequestId)")
    logger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
    
    return logger
}

/**
 Handler that manages the inbound channel for a HTTP Request.
 */
class HTTP1ChannelInboundHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    /**
     Internal state variable that tracks the progress
     of the HTTP Request and Response.
     */
    private enum State {
        case idle
        case waitingForRequestBody
        case sendingResponse

        mutating func requestReceived() {
            precondition(self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition(self == .waitingForRequestBody, "Invalid state for request complete: \(self)")
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
            self = .idle
        }
    }
    
    private let handler: HTTP1RequestHandler
    private let invocationStrategy: InvocationStrategy
    private var requestHead: HTTPRequestHead?
    private var requestAttributes: (Logger, String)?
    
    var partialBody: Data?
    private var keepAliveStatus = KeepAliveStatus()
    private var state = State.idle
    
    init(handler: HTTP1RequestHandler,
         invocationStrategy: InvocationStrategy) {
        self.handler = handler
        self.invocationStrategy = invocationStrategy
    }

    private func reset() {
        requestHead = nil
        requestAttributes = nil
        partialBody = nil
        keepAliveStatus = KeepAliveStatus()
        state = State.idle
    }
    
    private func getRequestAttributes() -> (Logger, String) {
        if let requestAttributes = requestAttributes {
            return requestAttributes
        } else {
            let internalRequestId = UUID().uuidString
            var logger = Logger(label: "com.amazon.SmokeFramework.request.\(internalRequestId)")
            logger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
            
            let newRequestAttributes = (logger, internalRequestId)
            requestAttributes = newRequestAttributes
            
            return newRequestAttributes
        }
    }
    
    /**
     Function called when the inbound channel receives data.
     */
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let request):
            reset()
            let (logger, _) = getRequestAttributes()
            
            // if this is the request head, store it and the keep alive status
            requestHead = request
            logger.debug("Request head received.")
            keepAliveStatus.state = request.isKeepAlive
            self.state.requestReceived()
        case .body(var byteBuffer):
            let byteBufferSize = byteBuffer.readableBytes
            let newData = byteBuffer.readData(length: byteBufferSize)
            
            if var newPartialBody = partialBody,
                let newData = newData {
                newPartialBody += newData
                partialBody = newPartialBody
            } else if let newData = newData {
                partialBody = newData
            }
            
            let (logger, _) = getRequestAttributes()
            logger.debug("Request body part of \(byteBufferSize) bytes received.")
        case .end:
            let (logger, internalRequestId) = getRequestAttributes()
            logger.debug("Request end received.")
            // this signals that the head and all possible body parts have been received
            self.state.requestComplete()
            handleCompleteRequest(context: context, bodyData: partialBody,
                                  logger: logger, internalRequestId: internalRequestId)
            reset()
        }
    }
    
    /**
     Is called when the request has been completed received
     and can be passed to the request hander.
     */
    func handleCompleteRequest(context: ChannelHandlerContext, bodyData: Data?,
                               logger: Logger, internalRequestId: String) {
        self.state.responseComplete()
        
        logger.debug("Handling request body with \(bodyData?.count ?? 0) size.")
        
        // make sure we have received the head
        guard let requestHead = requestHead else {
            logger.error("Unable to complete Http request as the head was not received")
            
            handleResponseAsError(context: context,
                                  responseString: "Missing request head.",
                                  status: .badRequest)
            
            return
        }
        
        // create a response handler for this request
        let responseHandler = StandardHTTP1ResponseHandler(
            requestHead: requestHead,
            keepAliveStatus: keepAliveStatus,
            context: context,
            wrapOutboundOut: wrapOutboundOut)
    
        let currentHandler = handler
        
        // pass to the request handler to complete
        currentHandler.handle(requestHead: requestHead,
                              body: bodyData,
                              responseHandler: responseHandler,
                              invocationStrategy: invocationStrategy,
                              requestLogger: logger,
                              internalRequestId: internalRequestId)
    }
    
    /**
     Called when reading from the channel is completed.
     */
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    /**
     Writes a error to the response and closes the channel.
     */
    func handleResponseAsError(context: ChannelHandlerContext,
                               responseString: String,
                               status: HTTPResponseStatus) {
        var headers = HTTPHeaders()
        var buffer = context.channel.allocator.buffer(capacity: responseString.utf8.count)
        buffer.setString(responseString, at: 0)
        
        headers.add(name: HTTP1Headers.contentLength, value: "\(responseString.utf8.count)")
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: requestHead!.version,
                                                              status: status,
                                                              headers: headers))), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                          promise: nil)
        context.close(promise: nil)
    }
    
    /**
     Called when an inbound event occurs.
     */
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        // if the remote peer half-closed the channel.
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            switch self.state {
            case .idle, .waitingForRequestBody:
                // not waiting on anything else, channel can be closed
                // immediately
                context.close(promise: nil)
            case .sendingResponse:
                // waiting on sending the response, signal that the
                // channel should be closed after sending the response.
                self.keepAliveStatus.state = false
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}
