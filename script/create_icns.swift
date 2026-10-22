#!/usr/bin/env swift

import Foundation

struct IconEntry {
    let type: String
    let filename: String
}

let entries = [
    IconEntry(type: "icp4", filename: "icon_16x16.png"),
    IconEntry(type: "icp5", filename: "icon_32x32.png"),
    IconEntry(type: "ic11", filename: "icon_16x16@2x.png"),
    IconEntry(type: "icp6", filename: "icon_32x32@2x.png"),
    IconEntry(type: "ic12", filename: "icon_32x32@2x.png"),
    IconEntry(type: "ic07", filename: "icon_128x128.png"),
    IconEntry(type: "ic08", filename: "icon_256x256.png"),
    IconEntry(type: "ic13", filename: "icon_128x128@2x.png"),
    IconEntry(type: "ic09", filename: "icon_512x512.png"),
    IconEntry(type: "ic14", filename: "icon_256x256@2x.png"),
    IconEntry(type: "ic10", filename: "icon_512x512@2x.png")
]

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: create_icns.swift ICONSET_DIR OUTPUT.icns\n".utf8))
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

func bigEndianData(_ value: Int) throws -> Data {
    guard value <= Int(UInt32.max) else {
        throw NSError(domain: "ICNS", code: 1, userInfo: [NSLocalizedDescriptionKey: "ICNS file is too large"])
    }
    var encoded = UInt32(value).bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

do {
    var chunks = Data()

    for entry in entries {
        guard let typeData = entry.type.data(using: .ascii), typeData.count == 4 else {
            throw NSError(domain: "ICNS", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS type: \(entry.type)"])
        }

        let imageData = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.filename))
        chunks.append(typeData)
        chunks.append(try bigEndianData(imageData.count + 8))
        chunks.append(imageData)
    }

    var container = Data("icns".utf8)
    container.append(try bigEndianData(chunks.count + 8))
    container.append(chunks)
    try container.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("Failed to create ICNS: \(error.localizedDescription)\n".utf8))
    exit(1)
}
