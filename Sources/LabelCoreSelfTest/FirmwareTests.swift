import Foundation
import LabelCore

func runFirmwareTests() throws {
    let rejected: [String?] = [nil, "", "1.1.48", "1.1.9", "1.0.99", "1.1", "1..49", "1.1.49.0", "1.1.49-beta", "x1.1.49", "-1.1.49", "999999999999999999999999999999.1.49"]
    for version in rejected {
        guard !MunbynFirmwareCapabilities.canPrint(.continuous, firmware: version) else {
            throw NSError(domain: "FirmwareTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsafe continuous stock unlock: \(version ?? "nil")"])
        }
        guard MunbynFirmwareCapabilities.canPrint(.gap, firmware: version) else {
            throw NSError(domain: "FirmwareTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Normal labels must remain available on legacy/unknown firmware"])
        }
    }
    for version in ["1.1.49", "1.1.50", "1.2.0", "1.10.0", "v1.1.49", "V1.1.49", " 1.1.49\n"] {
        guard MunbynFirmwareCapabilities.canPrint(.continuous, firmware: version) else {
            throw NSError(domain: "FirmwareTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "Supported firmware rejected: \(version)"])
        }
    }
    print("Firmware tests passed: numeric versions, malformed replies, legacy media guard and normal-label compatibility")
}
