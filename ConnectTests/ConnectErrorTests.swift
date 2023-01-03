// Copyright 2022 Buf Technologies, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import Connect
import Foundation
import Generated
import SwiftProtobuf
import XCTest

final class ConnectErrorTests: XCTestCase {
    func testDeserializingFullErrorAndUnpackingDetails() throws {
        let expectedDetails = Grpc_Testing_SimpleResponse.with { $0.hostname = "foobar" }
        let errorData = try self.errorData(expectedDetails: expectedDetails)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), expectedDetails)
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingErrorUsingHelperFunctionLowercasesHeaderKeys() throws {
        let expectedDetails = Grpc_Testing_SimpleResponse.with { $0.hostname = "foobar" }
        let errorData = try self.errorData(expectedDetails: expectedDetails)
        let error = ConnectError.from(
            code: .aborted,
            headers: [
                "sOmEkEy": ["foo"],
                "otherKey1": ["BAR", "bAz"],
            ],
            source: errorData
        )
        XCTAssertEqual(error.code, .unavailable) // Respects the code from the error body
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), expectedDetails)
        XCTAssertEqual(error.metadata, ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
    }

    func testDeserializingSimpleError() throws {
        let errorDictionary = [
            "code": "unavailable",
        ]
        let errorData = try JSONSerialization.data(withJSONObject: errorDictionary)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertNil(error.message)
        XCTAssertNil(error.exception)
        XCTAssertTrue(error.details.isEmpty)
        XCTAssertNil(error.unpackedDetails() as Grpc_Testing_SimpleResponse?)
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingEmptyDictionaryFails() throws {
        let errorData = try JSONSerialization.data(withJSONObject: [String: Any]())
        XCTAssertThrowsError(try JSONDecoder().decode(ConnectError.self, from: errorData))
    }

    // MARK: - Private

    private func errorData(expectedDetails: SwiftProtobuf.Message) throws -> Data {
        // Example error from https://connect.build/docs/protocol/#error-end-stream
        let dictionary: [String: Any] = [
            "code": "unavailable",
            "message": "overloaded: back off and retry",
            "details": [
                [
                    "type": type(of: expectedDetails).protoMessageName,
                    "value": try expectedDetails.serializedData().base64EncodedString(),
                    "debug": ["retryDelay": "30s"],
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: dictionary)
    }
}