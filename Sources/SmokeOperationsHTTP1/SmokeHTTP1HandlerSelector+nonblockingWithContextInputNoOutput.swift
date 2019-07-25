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
// SmokeHTTP1HandlerSelector+nonblockingWithContextInputNoOutput.swift
// SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import NIOHTTP1
import Logging

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForOperation<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeInvocationReporting, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        inputLocation: OperationInputHTTPLocation) {
        
        func outputProvider(input: InputType, context: ContextType,
                            invocationReporting: SmokeInvocationReporting, completion: @escaping (Swift.Error?) -> ()) throws {
            try operation(input, context, invocationReporting, completion)
        }
        
        // don't capture self
        let delegateToUse = defaultOperationDelegate
        func inputProvider(requestHead: DefaultOperationDelegateType.RequestHeadType, body: Data?) throws -> InputType {
            return try delegateToUse.getInputForOperation(
                requestHead: requestHead,
                body: body,
                location: inputLocation)
        }
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: inputProvider,
            operation: operation,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    mutating func addHandlerForOperation<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription,
        OperationDelegateType: HTTP1OperationDelegate>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeInvocationReporting, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        inputLocation: OperationInputHTTPLocation,
        operationDelegate: OperationDelegateType)
        where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
        DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            
            func outputProvider(input: InputType, context: ContextType,
                                invocationReporting: SmokeInvocationReporting, completion: @escaping (Swift.Error?) -> ()) throws {
                try operation(input, context, invocationReporting, completion)
            }
            
            func inputProvider(requestHead: OperationDelegateType.RequestHeadType, body: Data?) throws -> InputType {
                return try operationDelegate.getInputForOperation(
                    requestHead: requestHead,
                    body: body,
                    location: inputLocation)
            }
            
            let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
                inputProvider: inputProvider,
                operation: operation,
                allowedErrors: allowedErrors,
                operationDelegate: operationDelegate)
            
            addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForOperation<InputType: ValidatableOperationHTTP1InputProtocol,
        ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeInvocationReporting, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)]) {
        
        func outputProvider(input: InputType, context: ContextType,
                            invocationReporting: SmokeInvocationReporting, completion: @escaping (Swift.Error?) -> ()) throws {
            try operation(input, context, invocationReporting, completion)
        }
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: defaultOperationDelegate.getInputForOperation,
            operation: operation,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    mutating func addHandlerForOperation<InputType: ValidatableOperationHTTP1InputProtocol,
        ErrorType: ErrorIdentifiableByDescription,
        OperationDelegateType: HTTP1OperationDelegate>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeInvocationReporting, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        func outputProvider(input: InputType, context: ContextType,
                            invocationReporting: SmokeInvocationReporting, completion: @escaping (Swift.Error?) -> ()) throws {
            try operation(input, context, invocationReporting, completion)
        }
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: operationDelegate.getInputForOperation,
            operation: operation,
            allowedErrors: allowedErrors,
            operationDelegate: operationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
}
