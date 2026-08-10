#include <CoreFoundation/CoreFoundation.h>
#include <CoreMIDI/CoreMIDI.h>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <mach/mach_time.h>

extern "C" {

struct PbMidiEvent {
    uint64_t timestamp_us;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    uint8_t length;
};

}

namespace {
constexpr uint32_t Capacity = 1024;
PbMidiEvent queue[Capacity];
std::atomic<uint32_t> head{0};
std::atomic<uint32_t> tail{0};
std::atomic<uint64_t> dropped{0};
MIDIClientRef client = 0;
MIDIPortRef inputPort = 0;
MIDIEndpointRef connectedSource = 0;

uint64_t HostTimeToMicroseconds(uint64_t ticks) {
    static mach_timebase_info_data_t info = [] { mach_timebase_info_data_t value{}; mach_timebase_info(&value); return value; }();
    return ticks * info.numer / info.denom / 1000;
}

void Enqueue(PbMidiEvent event) {
    const auto currentHead = head.load(std::memory_order_relaxed);
    const auto next = (currentHead + 1) % Capacity;
    if (next == tail.load(std::memory_order_acquire)) {
        dropped.fetch_add(1, std::memory_order_relaxed);
        return;
    }
    queue[currentHead] = event;
    head.store(next, std::memory_order_release);
}

void ReadCallback(const MIDIPacketList* list, void*, void*) {
    auto packet = &list->packet[0];
    for (UInt32 packetIndex = 0; packetIndex < list->numPackets; ++packetIndex) {
        const auto timestamp = packet->timeStamp == 0 ? mach_absolute_time() : packet->timeStamp;
        for (UInt16 offset = 0; offset < packet->length;) {
            const uint8_t status = packet->data[offset];
            if ((status & 0x80) == 0) { ++offset; continue; }
            const uint8_t high = status & 0xF0;
            const uint8_t length = (high == 0xC0 || high == 0xD0) ? 2 : 3;
            if (offset + length > packet->length) break;
            Enqueue({HostTimeToMicroseconds(timestamp), status, packet->data[offset + 1],
                length == 3 ? packet->data[offset + 2] : uint8_t{0}, length});
            offset += length;
        }
        packet = MIDIPacketNext(packet);
    }
}

void Disconnect() {
    if (inputPort && connectedSource) MIDIPortDisconnectSource(inputPort, connectedSource);
    connectedSource = 0;
    if (inputPort) MIDIPortDispose(inputPort);
    inputPort = 0;
    if (client) MIDIClientDispose(client);
    client = 0;
}
}

extern "C" int pb_midi_port_count() { return static_cast<int>(MIDIGetNumberOfSources()); }

extern "C" int pb_midi_port_name(int index, char* output, int capacity) {
    if (!output || capacity <= 0 || index < 0 || index >= pb_midi_port_count()) return 0;
    CFStringRef name = nullptr;
    if (MIDIObjectGetStringProperty(MIDIGetSource(index), kMIDIPropertyName, &name) != noErr || !name) return 0;
    const bool copied = CFStringGetCString(name, output, capacity, kCFStringEncodingUTF8);
    CFRelease(name);
    return copied ? 1 : 0;
}

extern "C" int pb_midi_port_online(int index) {
    if (index < 0 || index >= pb_midi_port_count()) return 0;
    SInt32 offline = 0;
    const auto result = MIDIObjectGetIntegerProperty(MIDIGetSource(index), kMIDIPropertyOffline, &offline);
    return result != noErr || offline == 0 ? 1 : 0;
}

extern "C" int pb_midi_connect(int index) {
    Disconnect();
    if (index < 0 || index >= pb_midi_port_count() || pb_midi_port_online(index) == 0) return 0;
    if (MIDIClientCreate(CFSTR("PanBeat Unity MIDI"), nullptr, nullptr, &client) != noErr) { Disconnect(); return 0; }
    if (MIDIInputPortCreate(client, CFSTR("PanBeat Input"), ReadCallback, nullptr, &inputPort) != noErr) { Disconnect(); return 0; }
    connectedSource = MIDIGetSource(index);
    if (MIDIPortConnectSource(inputPort, connectedSource, nullptr) != noErr) { Disconnect(); return 0; }
    return 1;
}

extern "C" void pb_midi_disconnect() { Disconnect(); }

extern "C" int pb_midi_poll(PbMidiEvent* output) {
    if (!output) return 0;
    const auto currentTail = tail.load(std::memory_order_relaxed);
    if (currentTail == head.load(std::memory_order_acquire)) return 0;
    *output = queue[currentTail];
    tail.store((currentTail + 1) % Capacity, std::memory_order_release);
    return 1;
}

extern "C" uint64_t pb_midi_dropped_count() { return dropped.load(std::memory_order_relaxed); }
extern "C" void pb_midi_reset_queue() { head.store(0); tail.store(0); dropped.store(0); }
extern "C" void pb_midi_test_inject(uint64_t timestamp_us, uint8_t status, uint8_t data1, uint8_t data2) {
    Enqueue({timestamp_us, status, data1, data2, uint8_t{3}});
}
