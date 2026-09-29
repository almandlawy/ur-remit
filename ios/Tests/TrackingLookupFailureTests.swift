import XCTest
@testable import URRemit

final class TrackingLookupFailureTests: XCTestCase {
    func testNotFoundHttpStatusMapsToNonRetryableNotFound() {
        let failure = TrackingLookupFailure(NetworkError.httpStatus(404))
        XCTAssertEqual(failure, .notFound)
        XCTAssertFalse(failure.canRetry)
    }

    func testTransportErrorMapsToRetryableTransient() {
        let failure = TrackingLookupFailure(NetworkError.transport)
        XCTAssertEqual(failure, .transient)
        XCTAssertTrue(failure.canRetry)
    }

    func testOtherHttpStatusesAreTreatedAsTransientAndRetryable() {
        // A 500/503 is the backend or network having a bad moment, not proof the transfer doesn't
        // exist, so this should offer a retry rather than the permanent "not found" message.
        let failure = TrackingLookupFailure(NetworkError.httpStatus(503))
        XCTAssertEqual(failure, .transient)
        XCTAssertTrue(failure.canRetry)
    }

    func testDecodingErrorMapsToRetryableTransient() {
        let failure = TrackingLookupFailure(NetworkError.decoding)
        XCTAssertEqual(failure, .transient)
        XCTAssertTrue(failure.canRetry)
    }
}
