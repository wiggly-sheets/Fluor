//
//  FKeyManager.swift
// 
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Foundation
import IOKit

protocol FKeyModeManaging {
    func currentFKeyMode() throws -> FKeyMode
    @discardableResult func setCurrentFKeyMode(_ mode: FKeyMode) throws -> Bool
}

struct SystemFKeyModeManager: FKeyModeManaging {
    func currentFKeyMode() throws -> FKeyMode {
        try FKeyManager.getCurrentFKeyMode().get()
    }

    @discardableResult
    func setCurrentFKeyMode(_ mode: FKeyMode) throws -> Bool {
        try FKeyManager.setCurrentFKeyMode(mode)
    }
}

final class FKeyModeCoordinator {
    private let manager: FKeyModeManaging
    private let queue: DispatchQueue

    init(
        manager: FKeyModeManaging = SystemFKeyModeManager(),
        queue: DispatchQueue = DispatchQueue(label: "com.zm.fluor.keyboard-mode", qos: .userInitiated)
    ) {
        self.manager = manager
        self.queue = queue
    }

    func currentFKeyMode() -> Result<FKeyMode, Error> {
        queue.sync { Result { try manager.currentFKeyMode() } }
    }

    func apply(_ mode: FKeyMode, completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            let result = Result { try self.manager.setCurrentFKeyMode(mode) }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func applySynchronously(_ mode: FKeyMode) -> Result<Bool, Error> {
        queue.sync { Result { try manager.setCurrentFKeyMode(mode) } }
    }
}

enum FKeyManager {
    typealias FKeyManagerResult = Result<FKeyMode, Error>
    
    enum FKeyManagerError: LocalizedError {
        case cannotFindService
        case cannotGetParameter
        case cannotPersistPreference
        case cannotApplyPreferences
        case preferenceApplicationTimedOut
        case parameterDidNotChange

        var errorDescription: String? {
            switch self {
            case .cannotFindService:
                return "The keyboard state service could not be found (E1)"
            case .cannotGetParameter:
                return "Function-key mode could not be read (E2)"
            case .cannotPersistPreference:
                return "The macOS keyboard preference could not be saved (E3)"
            case .cannotApplyPreferences:
                return "The macOS keyboard preference could not be applied (E4)"
            case .preferenceApplicationTimedOut:
                return "macOS took too long to apply the keyboard preference (E5)"
            case .parameterDidNotChange:
                return "macOS accepted the function-key request but the mode did not change (E6)"
            }
        }
    }
    
    @discardableResult
    static func setCurrentFKeyMode(_ mode: FKeyMode) throws -> Bool {
        try setCurrentFKeyModeViaPreferences(mode)
    }

    // Modern macOS requires applying the global preference through activateSettings.
    private static func setCurrentFKeyModeViaPreferences(_ mode: FKeyMode) throws -> Bool {
        let originalMode = try getCurrentFKeyMode().get()
        guard originalMode != mode else { return false }
        try setFunctionKeyPreference(mode)

        do {
            try applySystemSettings()
            guard waitForCurrentFKeyMode(mode) else {
                throw FKeyManagerError.parameterDidNotChange
            }
        } catch {
            try? setFunctionKeyPreference(originalMode)
            try? applySystemSettings()
            throw error
        }

        return true
    }

    private static func waitForCurrentFKeyMode(
        _ mode: FKeyMode,
        timeout: TimeInterval = 2.0
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if (try? getCurrentFKeyMode().get()) == mode {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }

    private static func setFunctionKeyPreference(_ mode: FKeyMode) throws {
        let enabled = mode == .function ? kCFBooleanTrue : kCFBooleanFalse
        CFPreferencesSetValue(
            "com.apple.keyboard.fnState" as CFString,
            enabled,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            throw FKeyManagerError.cannotPersistPreference
        }
    }

    private static func applySystemSettings() throws {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        )
        process.arguments = ["-u"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            throw FKeyManagerError.cannotApplyPreferences
        }

        guard completion.wait(timeout: .now() + 5) == .success else {
            process.terminate()
            throw FKeyManagerError.preferenceApplicationTimedOut
        }

        guard process.terminationStatus == 0 else {
            throw FKeyManagerError.cannotApplyPreferences
        }
    }
    
    static func getCurrentFKeyMode() -> FKeyManagerResult {
        FKeyManagerResult {
            let entry = IORegistryEntryFromPath(
                kIOMainPortDefault,
                "IOService:/IOResources/IOHIDSystem"
            )
            guard entry != IO_OBJECT_NULL else {
                throw FKeyManagerError.cannotFindService
            }
            defer { IOObjectRelease(entry) }

            guard let parameters = IORegistryEntryCreateCFProperty(
                entry,
                "HIDParameters" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any],
            let rawMode = parameters[kIOHIDFKeyModeKey] as? NSNumber,
            let mode = FKeyMode(rawValue: rawMode.intValue) else {
                throw FKeyManagerError.cannotGetParameter
            }

            return mode
        }
    }
}
