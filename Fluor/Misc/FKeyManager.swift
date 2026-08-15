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

enum FKeyManager {
    typealias FKeyManagerResult = Result<FKeyMode, Error>
    
    enum FKeyManagerError: LocalizedError {
        case cannotGetParameter
        case cannotApplyPreferences
        case parameterDidNotChange

        var errorDescription: String? {
            switch self {
            case .cannotGetParameter:
                return "Function-key mode could not be read (E1)"
            case .cannotApplyPreferences:
                return "The macOS keyboard preference could not be applied (E2)"
            case .parameterDidNotChange:
                return "macOS accepted the function-key request but the mode did not change (E3)"
            }
        }
    }
    
    static func setCurrentFKeyMode(_ mode: FKeyMode) throws {
        try setCurrentFKeyModeViaPreferences(mode)
    }

    // Modern macOS requires applying the global preference through activateSettings.
    private static func setCurrentFKeyModeViaPreferences(_ mode: FKeyMode) throws {
        let originalMode = try getCurrentFKeyMode().get()
        setFunctionKeyPreference(mode)

        do {
            try applySystemSettings()
            guard waitForCurrentFKeyMode(mode) else {
                throw FKeyManagerError.parameterDidNotChange
            }
        } catch {
            setFunctionKeyPreference(originalMode)
            try? applySystemSettings()
            throw error
        }
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

    private static func setFunctionKeyPreference(_ mode: FKeyMode) {
        let enabled = mode == .function ? kCFBooleanTrue : kCFBooleanFalse
        CFPreferencesSetValue(
            "com.apple.keyboard.fnState" as CFString,
            enabled,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    private static func applySystemSettings() throws {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        )
        process.arguments = ["-u"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw FKeyManagerError.cannotApplyPreferences
        }

        guard process.terminationStatus == 0 else {
            throw FKeyManagerError.cannotApplyPreferences
        }
    }
    
    static func getCurrentFKeyMode() -> FKeyManagerResult {
        FKeyManagerResult {
            guard let enabled = CFPreferencesCopyValue(
                "com.apple.keyboard.fnState" as CFString,
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? Bool else {
                throw FKeyManagerError.cannotGetParameter
            }

            return enabled ? .function : .media
        }
    }
}
