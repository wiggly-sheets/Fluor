import Foundation
import XCTest

final class FKeyModeCoordinatorTests: XCTestCase {
    func testCurrentModeIsReadThroughCoordinator() throws {
        let manager = FakeFKeyModeManager(mode: .function)
        let coordinator = FKeyModeCoordinator(manager: manager)

        XCTAssertEqual(try coordinator.currentFKeyMode().get(), .function)
    }

    func testApplicationsAreSerializedInSubmissionOrder() {
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
            if case .success = result {
                XCTFail("Expected the manager error to be returned")
            }
            completion.fulfill()
        }

        wait(for: [completion], timeout: 2)
    }
}

private enum FakeError: Error {
    case expected
}

private final class FakeFKeyModeManager: FKeyModeManaging {
    private let lock = NSLock()
    private var mode: FKeyMode
    private var modes: [FKeyMode] = []
    var nextError: Error?

    init(mode: FKeyMode) {
        self.mode = mode
    }

    var appliedModes: [FKeyMode] {
        lock.withLock { modes }
    }

    func currentFKeyMode() throws -> FKeyMode {
        lock.withLock { mode }
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
