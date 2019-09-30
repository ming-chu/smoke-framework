# SmokeFramework 2.0 Release Plan

The following document describes the process for release version 2.0 of SmokeFramework and related Smoke repositories such as SmokeHTTP and SmokeAWS.

## High Level Goals

The high level goals for this release are-

1. Require Swift 5.0+ compatibility
2. Adopt Swift.Result rather than our own Result types. 
3. Adopt SwiftNio 2 (https://github.com/apple/swift-nio)
4. Adopt SwiftLog 1 (https://github.com/apple/swift-log)
5. Use explicitly-passed per-request loggers
6. Adopt SwiftMetrics 1 (https://github.com/apple/swift-metrics)
7. Support CI Tests on Ubuntu bionic and xenial
8. Support openssl 1.0 or 1.1 (whatever is native to the current system)
9. Expose SmokeHTTP response codes by wrapping the error type returned

## Goal Details

### Require Swift 5.0+ compatibility

This is required to adopt SwiftNIO 2 and as such will likely be the baseline compatibility going forward.

**Backwards Compatibility:** 

### Adopt Swift.Result rather than our own Result types

This represents a rather significant breaking change to all APIs (such as in SmokeAWS) but on the
flip-side increases compatibility between the Smoke libraries and the rest of the Swift eco-system.

This change will require consumers to change references to the Smoke Result types to the Swift.Result type
(they have different enumeration values).

### Adopt SwiftNIO 2

This is the updated version of SwiftNIO and the Smoke repositories will eventually have to migrate to it.

### Adopt SwiftLog 1

This change increases compatibility between the Smoke libraries and the rest of the Swift eco-system.

### Use explicitly-passed per-request loggers

This also represents a rather significant breaking change to all APIs but enables enhanced tagging of log messages to
the request they correspond to.

### Adopt SwiftMetrics 1

The standardization of a metrics API allows the Smoke repositories to emit metrics around requests.

## Release Timeline

The timeline and actions for this release-

1. Cut 1.0 branches of all repositories for bug fixes, leaving master branch development for 2.0.
2. Submit PRs for the changes required
3. Release Alpha 1.


