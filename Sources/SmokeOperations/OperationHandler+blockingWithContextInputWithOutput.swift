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
// OperationHandler+blockingWithContextInputWithOutput.swift
// SmokeOperations
//

import Foundation
import Logging

public extension OperationHandler {
    /**
      Initializer for blocking operation handler that has input returns
      a result body.
     
     - Parameters:
        - inputProvider: function that obtains the input from the request.
        - operation: the handler method for the operation.
        - outputHandler: function that completes the response with the provided output.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation.
     */
    init<InputType: Validatable, OutputType: Validatable, ErrorType: ErrorIdentifiableByDescription,
        OperationDelegateType: OperationDelegate>(
            serverName: String, operationIdentifer: OperationIdentifer, reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer>,
            inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
            operation: @escaping (InputType, ContextType, SmokeInvocationReporting) throws -> OutputType,
            outputHandler: @escaping ((RequestHeadType, OutputType, ResponseHandlerType, SmokeInvocationContext) -> Void),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        /**
         * The wrapped input handler takes the provided operation handler and wraps it so that if it
         * returns, the responseHandler is called with the result. If the provided operation
         * throws an error, the responseHandler is called with that error.
         */
        let wrappedInputHandler = { (input: InputType, requestHead: RequestHeadType, context: ContextType,
                                     responseHandler: OperationDelegateType.ResponseHandlerType,
                                     invocationContext: SmokeInvocationContext) in
            let handlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>
            do {
                let output = try operation(input, context, invocationContext.invocationReporting)
                
                handlerResult = .success(output)
            } catch let smokeReturnableError as SmokeReturnableError {
                handlerResult = .smokeReturnableError(smokeReturnableError, allowedErrors)
            } catch SmokeOperationsError.validationError(reason: let reason) {
                handlerResult = .validationError(reason)
            } catch {
                handlerResult = .internalServerError(error)
            }
            
            OperationHandler.handleWithOutputOperationHandlerResult(
                handlerResult: handlerResult,
                operationDelegate: operationDelegate,
                requestHead: requestHead,
                responseHandler: responseHandler,
                outputHandler: outputHandler,
                invocationContext: invocationContext)
        }
        
        self.init(serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
                  inputHandler: wrappedInputHandler,
                  inputProvider: inputProvider,
                  operationDelegate: operationDelegate)
    }
}
