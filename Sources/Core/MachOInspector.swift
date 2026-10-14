import Foundation

/// Reads CPU types from Mach-O headers without launching the installed app or
/// requiring `lipo`, Xcode tools, or a subprocess on the inspected laptop.
enum MachOInspector {
    static func architectures(at executable: URL) throws -> [String] {
        let handle = try FileHandle(forReadingFrom: executable)
        defer { try? handle.close() }
        // A bounded header read is enough for normal thin and Universal binaries.
        return architectures(in: try handle.read(upToCount: 65_536) ?? Data())
    }

    static func architectures(in data: Data) -> [String] {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { return [] }
        let magic = Array(bytes.prefix(4))
        let littleEndian: Bool
        let fatStride: Int?

        switch magic {
        case [0xCE, 0xFA, 0xED, 0xFE], [0xCF, 0xFA, 0xED, 0xFE]:
            littleEndian = true
            fatStride = nil
        case [0xFE, 0xED, 0xFA, 0xCE], [0xFE, 0xED, 0xFA, 0xCF]:
            littleEndian = false
            fatStride = nil
        case [0xCA, 0xFE, 0xBA, 0xBE]:
            littleEndian = false
            fatStride = 20
        case [0xBE, 0xBA, 0xFE, 0xCA]:
            littleEndian = true
            fatStride = 20
        case [0xCA, 0xFE, 0xBA, 0xBF]:
            littleEndian = false
            fatStride = 32
        case [0xBF, 0xBA, 0xFE, 0xCA]:
            littleEndian = true
            fatStride = 32
        default:
            return []  // Script launchers and other formats cannot establish an architecture.
        }

        func word(at offset: Int) -> UInt32 {
            let slice = bytes[offset..<(offset + 4)]
            let ordered = littleEndian ? Array(slice.reversed()) : Array(slice)
            return ordered.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }

        var offsets = [4]
        if let stride = fatStride {
            let count = Int(word(at: 4))
            // Validate before reading: malformed installed files must not crash a scan.
            guard count > 0, count <= (bytes.count - 8) / stride else { return [] }
            offsets = (0..<count).map { 8 + $0 * stride }
        }
        return Array(Set(offsets.map { cpuName(type: word(at: $0), subtype: word(at: $0 + 4)) })).sorted()
    }

    static func kind(for architectures: [String]) -> ApplicationKind {
        let arm = architectures.contains("arm64") || architectures.contains("arm64e")
        let intel = architectures.contains("x86_64") || architectures.contains("i386")
        if arm && intel { return .universal }
        if arm { return .appleSilicon }
        if intel { return .intel }
        return architectures.isEmpty ? .unknown : .legacy
    }

    private static func cpuName(type: UInt32, subtype: UInt32) -> String {
        switch type {
        case 7: return "i386"
        case 0x01000007: return "x86_64"
        case 12: return "arm"
        case 0x0100000C: return subtype & 0x00FFFFFF == 2 ? "arm64e" : "arm64"
        case 18: return "ppc"
        case 0x01000012: return "ppc64"
        default: return "CPU \(type)"
        }
    }
}
