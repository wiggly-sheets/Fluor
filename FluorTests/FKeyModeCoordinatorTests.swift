import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import Fluor
#endif

final class FKeyModeCoordinatorTests: XCTestCase {
    func testModeChangesApplyInSubmissionOrder() {
        let manager = FakeFKeyModeManager(mode: .media)
        let coordinator = FKeyModeCoordinator(manager: manager)
        let completion = expectation(description: "Both mode changes complete")
        completion.expectedFulfillmentCount = 2
        var results: [Bool] = []

        coordinator.apply(.function) { result in
            results.append((try? result.get()) ?? false)
            completion.fulfill()
        }
        coordinator.apply(.media) { result in
            results.append((try? result.get()) ?? false)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 2)
        XCTAssertEqual(manager.appliedModes, [.function, .media])
        XCTAssertEqual(results, [true, true])
    }

    func testManagerFailureIsReturnedToCaller() {
        let manager = FakeFKeyModeManager(mode: .media)
        manager.nextError = FakeError.expected
        let coordinator = FKeyModeCoordinator(manager: manager)
        let completion = expectation(description: "Failure is returned")

        coordinator.apply(.function) { result in
            switch result {
            case .failure(let error):
                XCTAssertEqual(error as? FakeError, .expected)
            case .success:
                XCTFail("Expected the manager error to be returned")
            }
            completion.fulfill()
        }

        wait(for: [completion], timeout: 2)
    }

    func testCurrentModeReadFailureIsPropagated() {
        let manager = FakeFKeyModeManager(mode: .media)
        manager.currentError = FakeError.expected
        let coordinator = FKeyModeCoordinator(manager: manager)

        guard case .failure(let error) = coordinator.currentFKeyMode() else {
            return XCTFail("Expected the manager error to be returned")
        }
        XCTAssertEqual(error as? FakeError, .expected)
    }
}

private enum FakeError: Error, Equatable {
    case expected
}

private final class FakeFKeyModeManager: FKeyModeManaging {
    private let lock = NSLock()
    private var mode: FKeyMode
    private var modes: [FKeyMode] = []
    var nextError: Error?
    var currentError: Error?

    init(mode: FKeyMode) {
        self.mode = mode
    }

    var appliedModes: [FKeyMode] {
        lock.withLock { modes }
    }

    func currentFKeyMode() throws -> FKeyMode {
        try lock.withLock {
            if let error = currentError {
                currentError = nil
                throw error
            }
            return mode
        }
    }

    func setCurrentFKeyMode(_ mode: FKeyMode) throws -> Bool {
        try lock.withLock {
            if let error = nextError {
                nextError = nil
                throw error
            }
            modes.append(mode)
            let changed = self.mode != mode
            self.mode = mode
            return changed
        }
    }
}
