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
// OperationHandler.swift
// SmokeOperations
//

import Foundation
import Logging

/**
 Struct that handles serialization and de-serialization of request and response
 bodies from and to the shapes required by operation handlers.
 */
public struct OperationHandler<ContextType, RequestHeadType, ResponseHandlerType> {
    public typealias OperationResultValidatableInputFunction<InputType: Validatable>
        = (_ input: InputType, _ requestHead: RequestHeadType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType, _ invocationContext: SmokeInvocationContext) -> ()
    public typealias OperationResultDataInputFunction
        = (_ requestHead: RequestHeadType, _ body: Data?, _ context: ContextType,
        _ responseHandler: ResponseHandlerType, _ invocationStrategy: InvocationStrategy,
        _ requestLogger: Logger) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    private let operationReporting: SmokeOperationReporting
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ requestHead: RequestHeadType, body: Data?, withContext context: ContextType,
                       responseHandler: ResponseHandlerType, invocationStrategy: InvocationStrategy,
                       requestLogger: Logger) {
        return operationFunction(requestHead, body, context, responseHandler, invocationStrategy, requestLogger)
    }
    
    private enum InputDecodeResult<InputType: Validatable> {
        case ok(input: InputType, inputHandler: OperationResultValidatableInputFunction<InputType>, invocationContext: SmokeInvocationContext)
        case error(description: String, reportableType: String?, invocationContext: SmokeInvocationContext)
        
        func handle<OperationDelegateType: OperationDelegate>(
                requestHead: RequestHeadType, context: ContextType,
                responseHandler: ResponseHandlerType, operationDelegate: OperationDelegateType)
            where RequestHeadType == OperationDelegateType.RequestHeadType,
            ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch self {
            case .error(description: let description, reportableType: let reportableType, invocationContext: let invocationContext):
                let logger = invocationContext.invocationReporting.logger
                
                if let reportableType = reportableType {
                    logger.error("DecodingError [\(reportableType): \(description)")
                } else {
                    logger.error("DecodingError: \(description)")
                }
                
                operationDelegate.handleResponseForDecodingError(
                    requestHead: requestHead,
                    message: description,
                    responseHandler: responseHandler, invocationContext: invocationContext)
            case .ok(input: let input, inputHandler: let inputHandler, invocationContext: let invocationContext):
                let logger = invocationContext.invocationReporting.logger
                
                do {
                    // attempt to validate the input
                    try input.validate()
                } catch SmokeOperationsError.validationError(let reason) {
                    logger.warning("ValidationError: \(reason)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: reason,
                        responseHandler: responseHandler,
                        invocationContext: invocationContext)
                    return
                } catch {
                    logger.warning("ValidationError: \(error)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: nil,
                        responseHandler: responseHandler,
                        invocationContext: invocationContext)
                    return
                }
                
                inputHandler(input, requestHead, context, responseHandler, invocationContext)
            }
        }
    }
    
    /**
     Initialier that accepts the function to use to handle this operation.
 
     - Parameters:
        - operationFunction: the function to use to handle this operation.
     */
    public init(uri: String, operationFunction: @escaping OperationResultDataInputFunction) {
        self.operationFunction = operationFunction
        self.operationReporting = StandardSmokeOperationReporting(uri: uri)
    }
    
    /**
     * Convenience initializer that incorporates decoding and validating
     */
    public init<InputType: Validatable, OperationDelegateType: OperationDelegate>(
        uri: String,
        inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
        operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        let newOperationReporting = StandardSmokeOperationReporting(uri: uri)
        
        func getInvocationContextForAnonymousRequest(requestLogger: Logger) -> SmokeInvocationContext {
            let invocationReporting = operationDelegate.getInvocationReportingForAnonymousRequest(requestLogger: requestLogger)
            
            return SmokeInvocationContext(invocationReporting: invocationReporting,
                                          operationReporting: newOperationReporting)
        }
        
        let newFunction: OperationResultDataInputFunction = { (requestHead, body, context, responseHandler,
                                                               invocationStrategy, requestLogger) in
            let inputDecodeResult: InputDecodeResult<InputType>
            do {
                // decode the response within the event loop of the server to limit the number of request
                // `Data` objects that exist at single time to the number of threads in the event loop
                let input: InputType = try inputProvider(requestHead, body)
                
                let invocationReporting: SmokeInvocationReporting
                // if the input is a source for invocation reporting
                if let smokeInvocationReportingSource = input as? SmokeInvocationReportingSource {
                    invocationReporting = smokeInvocationReportingSource.getInvocationReporting(requestLogger: requestLogger)
                } else {
                    // use the anonymous invocation reporting
                    invocationReporting = operationDelegate.getInvocationReportingForAnonymousRequest(requestLogger: requestLogger)
                }
                
                let invocationContext = SmokeInvocationContext(invocationReporting: invocationReporting,
                                                              operationReporting: newOperationReporting)
                
                inputDecodeResult = .ok(input: input, inputHandler: inputHandler, invocationContext: invocationContext)
            } catch DecodingError.keyNotFound(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(requestLogger: requestLogger)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.valueNotFound(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(requestLogger: requestLogger)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.typeMismatch(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(requestLogger: requestLogger)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.dataCorrupted(let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(requestLogger: requestLogger)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch {
                let invocationContext = getInvocationContextForAnonymousRequest(requestLogger: requestLogger)
                let errorType = type(of: error)
                inputDecodeResult = .error(description: "\(error)", reportableType: "\(errorType)",
                                           invocationContext: invocationContext)
            }
            
            // continue the execution of the request according to the `invocationStrategy`
            // To avoid retaining the original body `Data` object, `body` should not be referenced in this
            // invocation.
            invocationStrategy.invoke {
                inputDecodeResult.handle(
                    requestHead: requestHead,
                    context: context,
                    responseHandler: responseHandler,
                    operationDelegate: operationDelegate)
            }
        }
        
        self.operationFunction = newFunction
        self.operationReporting = newOperationReporting
    }
}
