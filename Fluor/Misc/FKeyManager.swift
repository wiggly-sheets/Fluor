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


enum FKeyManager {
    typealias FKeyManagerResult = Result<FKeyMode, Error>
    
    enum FKeyManagerError: LocalizedError {
        case cannotCreateMasterPort
        case cannotFindService
        case cannotOpenService
        case cannotSetParameter
        case cannotGetParameter
        case cannotApplyPreferences
        case parameterDidNotChange

        var errorDescription: String? {
            switch self {
            case .cannotCreateMasterPort:
                return "Master port creation failed (E1)"
            case .cannotFindService:
                return "IOHIDSystem service was not found (E2)"
            case .cannotOpenService:
                return "Service opening failed (E3)"
            case .cannotSetParameter:
                return "Function-key mode could not be set (E4)"
            case .cannotGetParameter:
                return "Function-key mode could not be read (E5)"
            case .cannotApplyPreferences:
                return "The macOS keyboard preference could not be applied (E6)"
            case .parameterDidNotChange:
                return "macOS accepted the function-key request but the mode did not change (E7)"
            }
        }
    }
    
    static func setCurrentFKeyMode(_ mode: FKeyMode) throws {
        if #available(macOS 13.0, *) {
            try setCurrentFKeyModeViaPreferences(mode)
            return
        }

        let connect = try FKeyManager.getServiceConnect()
        defer { IOServiceClose(connect) }
        let value = mode.rawValue as CFNumber

        guard IOHIDSetCFTypeParameter(connect, kIOHIDFKeyModeKey as CFString, value) == KERN_SUCCESS else {
            throw FKeyManagerError.cannotSetParameter
        }

        guard try getCurrentFKeyMode().get() == mode else {
            throw FKeyManagerError.parameterDidNotChange
        }
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
            let ri = try self.getIORegistry()
            defer { IOObjectRelease(ri) }
            
            guard let entry = IORegistryEntryCreateCFProperty(
                ri,
                "HIDParameters" as CFString,
                kCFAllocatorDefault,
                0
            ) else {
                throw FKeyManagerError.cannotGetParameter
            }

            guard let dict = entry.takeRetainedValue() as? NSDictionary,
                let mode = dict.value(forKey: "HIDFKeyMode") as? Int,
                let currentMode = FKeyMode(rawValue: mode) else {
                    throw FKeyManagerError.cannotGetParameter
            }
            
            return currentMode
        }
    }
    
    private static func getIORegistry() throws -> io_registry_entry_t {
        var masterPort: mach_port_t = .zero
        guard IOMasterPort(bootstrap_port, &masterPort) == KERN_SUCCESS else { throw FKeyManagerError.cannotCreateMasterPort }
        
        let entry = IORegistryEntryFromPath(masterPort, "IOService:/IOResources/IOHIDSystem")
        guard entry != IO_OBJECT_NULL else { throw FKeyManagerError.cannotFindService }
        return entry
    }
    
    private static func getIOHandle() throws -> io_service_t {
        try self.getIORegistry() as io_service_t
    }
    
    private static func getServiceConnect() throws -> io_connect_t {
        var service: io_connect_t = .zero
        let handle = try self.getIOHandle()
        defer { IOObjectRelease(handle) }
        
        guard IOServiceOpen(handle, mach_task_self_, UInt32(kIOHIDParamConnectType), &service) == KERN_SUCCESS else {
            throw FKeyManagerError.cannotOpenService
        }
        
        return service
    }
}
