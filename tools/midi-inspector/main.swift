import CoreMIDI
import Darwin
import Foundation

let schemaVersion = "1.0.0"

func usage() {
    print("""
    Usage:
      scripts/midi-inspector list
      scripts/midi-inspector capture --port INDEX --output PATH [--label TEXT]
      scripts/midi-inspector synthetic --output PATH [--hold]

    capture writes schema 1.0.0 JSON Lines until Ctrl-C or SIGTERM.
    """)
}

func endpointName(_ endpoint: MIDIEndpointRef) -> String {
    var value: Unmanaged<CFString>?
    guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value) == noErr,
          let string = value?.takeRetainedValue() else { return "Unnamed MIDI source" }
    return string as String
}

func messageLength(_ status: UInt8) -> Int {
    switch status & 0xF0 {
    case 0xC0, 0xD0: return 2
    case 0x80...0xE0: return 3
    default: return 1
    }
}

func splitMessages(_ bytes: [UInt8]) -> [[UInt8]] {
    var result: [[UInt8]] = []
    var index = 0
    var runningStatus: UInt8?
    while index < bytes.count {
        var status = bytes[index]
        var message: [UInt8] = []
        if status >= 0x80 {
            index += 1
            if status < 0xF0 { runningStatus = status }
            else { runningStatus = nil }
            message.append(status)
        } else if let running = runningStatus {
            status = running
            message.append(status)
        } else {
            result.append(Array(bytes[index...]))
            break
        }
        if status >= 0xF0 {
            message.append(contentsOf: bytes[index...])
            index = bytes.count
        } else {
            let needed = messageLength(status) - 1
            let available = min(needed, bytes.count - index)
            message.append(contentsOf: bytes[index..<(index + available)])
            index += available
        }
        result.append(message)
    }
    return result
}

func decodedRecord(bytes: [UInt8], sessionID: String, sequence: Int, timestampUs: UInt64) -> [String: Any] {
    let status = bytes.first ?? 0
    let family = status & 0xF0
    let velocityZeroNoteOn = family == 0x90 && bytes.count > 2 && bytes[2] == 0
    let type: String
    switch family {
    case 0x80: type = "note_off"
    case 0x90: type = velocityZeroNoteOn ? "note_off" : "note_on"
    case 0xA0: type = "poly_pressure"
    case 0xB0: type = "control_change"
    case 0xC0: type = "program_change"
    case 0xD0: type = "channel_pressure"
    case 0xE0: type = "pitch_bend"
    default: type = "system"
    }
    var record: [String: Any] = [
        "schema_version": schemaVersion, "record_type": "event", "session_id": sessionID,
        "sequence": sequence, "timestamp_us": timestampUs, "clock_domain": "monotonic",
        "raw_bytes": bytes.map(Int.init), "message_type": type
    ]
    if status < 0xF0 {
        let wire = Int(status & 0x0F)
        record["channel_wire"] = wire
        record["channel_display"] = wire + 1
        if bytes.count > 1 { record["data1"] = Int(bytes[1]) }
        if bytes.count > 2 { record["data2"] = Int(bytes[2]) }
    }
    return record
}

final class CaptureContext {
    private let handle: FileHandle
    private let lock = NSLock()
    private(set) var sequence = 0
    let sessionID: String

    init(output: String, deviceName: String, portIndex: Int?, label: String?, synthetic: Bool) throws {
        sessionID = UUID().uuidString.lowercased()
        let url = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: output, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        var header: [String: Any] = [
            "schema_version": schemaVersion, "record_type": "session", "session_id": sessionID,
            "started_at": ISO8601DateFormatter().string(from: Date()), "clock_domain": "monotonic",
            "time_unit": "microseconds", "device_name": deviceName,
            "source_kind": synthetic ? "synthetic" : "core_midi"
        ]
        if let portIndex { header["port_index"] = portIndex }
        if let label { header["human_label"] = label }
        write(header)
    }

    func receive(_ bytes: [UInt8], timestampUs: UInt64 = DispatchTime.now().uptimeNanoseconds / 1_000) {
        lock.lock(); defer { lock.unlock() }
        for message in splitMessages(bytes) {
            write(decodedRecord(bytes: message, sessionID: sessionID, sequence: sequence, timestampUs: timestampUs))
            sequence += 1
        }
    }

    private func write(_ object: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        handle.write(data); handle.write(Data([0x0A])); try? handle.synchronize()
    }

    func finish() { lock.lock(); defer { lock.unlock() }; try? handle.synchronize(); try? handle.close() }
}

func option(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { usage(); exit(64) }
if command == "--help" || command == "-h" || command == "help" { usage(); exit(0) }

if command == "list" {
    let count = MIDIGetNumberOfSources()
    if count == 0 { print("No MIDI input sources found."); exit(0) }
    for index in 0..<count { print("\(index)\t\(endpointName(MIDIGetSource(index)))") }
    exit(0)
}

guard let output = option("--output", in: arguments) else { fputs("midi-inspector: --output is required\n", stderr); exit(64) }

if command == "synthetic" {
    let context = try CaptureContext(output: output, deviceName: "PanBeat Synthetic MIDI", portIndex: nil, label: "automated-test", synthetic: true)
    context.receive([0x90, 60, 100], timestampUs: 1_000_000)
    context.receive([0x90, 60, 0], timestampUs: 1_001_000)
    context.receive([0x81, 62, 64], timestampUs: 1_002_000)
    context.receive([0xB1, 7, 99], timestampUs: 1_003_000)
    if arguments.contains("--hold") {
        signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
        var sources: [DispatchSourceSignal] = []
        for value in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: value, queue: .main)
            source.setEventHandler { context.finish(); exit(0) }
            source.resume(); sources.append(source)
        }
        print("Synthetic live session; press Ctrl-C to stop. Output: \(output)")
        dispatchMain()
    }
    context.finish(); print("Wrote synthetic trace to \(output)"); exit(0)
}

guard command == "capture", let portText = option("--port", in: arguments), let portIndex = Int(portText) else {
    fputs("midi-inspector: capture requires --port INDEX\n", stderr); exit(64)
}
guard portIndex >= 0 && portIndex < MIDIGetNumberOfSources() else { fputs("midi-inspector: MIDI port index is unavailable\n", stderr); exit(1) }
let source = MIDIGetSource(portIndex)
let context = try CaptureContext(output: output, deviceName: endpointName(source), portIndex: portIndex, label: option("--label", in: arguments), synthetic: false)
var client = MIDIClientRef(); var inputPort = MIDIPortRef()
guard MIDIClientCreate("PanBeat MIDI Inspector" as CFString, nil, nil, &client) == noErr else { fputs("midi-inspector: cannot create MIDI client\n", stderr); exit(1) }
let opaque = Unmanaged.passUnretained(context).toOpaque()
let status = MIDIInputPortCreate(client, "Input" as CFString, { packetList, refCon, _ in
    guard let refCon else { return }
    let receiver = Unmanaged<CaptureContext>.fromOpaque(refCon).takeUnretainedValue()
    withUnsafeMutablePointer(to: &UnsafeMutablePointer(mutating: packetList).pointee.packet) { first in
        var packet = first
        for _ in 0..<packetList.pointee.numPackets {
            let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(Int(packet.pointee.length))) }
            receiver.receive(bytes)
            packet = MIDIPacketNext(packet)
        }
    }
}, opaque, &inputPort)
guard status == noErr && MIDIPortConnectSource(inputPort, source, nil) == noErr else { fputs("midi-inspector: cannot connect MIDI source\n", stderr); exit(1) }
signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)
var signalSources: [DispatchSourceSignal] = []
for value in [SIGINT, SIGTERM] {
    let signalSource = DispatchSource.makeSignalSource(signal: value, queue: .main)
    signalSource.setEventHandler { context.finish(); exit(0) }
    signalSource.resume(); signalSources.append(signalSource)
}
print("Capturing \(endpointName(source)); press Ctrl-C to stop. Output: \(output)")
dispatchMain()
