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
//  SmokeOperationReporting.swift
//  SmokeOperations
//
import Foundation
import Logging
import Metrics

/**
 A context related to reporting on a Smoke Operation
 */
public protocol SmokeOperationReporting {

    /// The `Metrics.Counter` to record the success of this invocation.
    var successCounter: Metrics.Counter? { get }

    /// The `Metrics.Counter` to record the failure of this invocation.
    var failure5XXCounter: Metrics.Counter? { get }
    
    /// The `Metrics.Counter` to record the failure of this invocation.
    var failure4XXCounter: Metrics.Counter? { get }

    /// The `Metrics.Recorder` to record the duration of this invocation.
    var latencyTimer: Metrics.Timer? { get }
}

public struct StandardSmokeOperationReporting: SmokeOperationReporting {
    public let successCounter: Metrics.Counter?
    public let failure5XXCounter: Metrics.Counter?
    public let failure4XXCounter: Metrics.Counter?
    public let latencyTimer: Metrics.Timer?
    
    private let namespaceDimension = "Namespace"
    private let uriDimension = "Operation Name"
    private let metricNameDimension = "Metric Name"
    
    private let serverNamespace = "Server"
    
    private let successCountMetric = "successCount"
    private let failure5XXCountMetric = "failure5XXCount"
    private let failure4XXCountMetric = "failure4XXCount"
    private let latencyTimeMetric = "latencyTime"
    
    public init(uri: String) {
        let successCounterDimensions = [(namespaceDimension, serverNamespace),
                                        (uriDimension, uri),
                                        (metricNameDimension, successCountMetric)]
        successCounter = Counter(label: "com.example.\(uri).\(successCountMetric)",
                                 dimensions: successCounterDimensions)
        
        let failure5XXCounterDimensions = [(namespaceDimension, serverNamespace),
                                           (uriDimension, uri),
                                           (metricNameDimension, failure5XXCountMetric)]
        failure5XXCounter = Counter(label: "com.example.\(uri).\(failure5XXCountMetric)",
                                    dimensions: failure5XXCounterDimensions)
        
        let failure4XXCounterDimensions = [(namespaceDimension, serverNamespace),
                                           (uriDimension, uri),
                                           (metricNameDimension, failure4XXCountMetric)]
        failure4XXCounter = Counter(label: "com.example.\(uri).\(failure4XXCountMetric)",
                                    dimensions: failure4XXCounterDimensions)
        
        let latencyTimeDimensions = [(namespaceDimension, serverNamespace),
                                     (uriDimension, uri),
                                     (metricNameDimension, latencyTimeMetric)]
        latencyTimer = Metrics.Timer(label: "com.example.\(uri).\(latencyTimeMetric)",
                                     dimensions: latencyTimeDimensions)
    }
}
