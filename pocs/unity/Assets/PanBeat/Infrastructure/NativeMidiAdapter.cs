using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace PanBeat.Infrastructure
{
    [StructLayout(LayoutKind.Sequential)]
    public struct NativeMidiEvent
    {
        public ulong TimestampMicroseconds;
        public byte Status;
        public byte Data1;
        public byte Data2;
        public byte Length;
    }

    public sealed class NativeMidiAdapter : IDisposable
    {
        private const string Library = "PanBeatMidi";

        [DllImport(Library)] private static extern int pb_midi_port_count();
        [DllImport(Library)] private static extern int pb_midi_port_name(int index, byte[] output, int capacity);
        [DllImport(Library)] private static extern int pb_midi_port_online(int index);
        [DllImport(Library)] private static extern int pb_midi_connect(int index);
        [DllImport(Library)] private static extern void pb_midi_disconnect();
        [DllImport(Library)] private static extern int pb_midi_poll(out NativeMidiEvent output);
        [DllImport(Library)] private static extern ulong pb_midi_dropped_count();
        [DllImport(Library)] internal static extern void pb_midi_reset_queue();
        [DllImport(Library)] internal static extern void pb_midi_test_inject(ulong timestamp, byte status, byte data1, byte data2);

        public int PortCount => pb_midi_port_count();
        public ulong DroppedCount => pb_midi_dropped_count();
        public bool IsConnected { get; private set; }

        public string GetPortName(int index)
        {
            var bytes = new byte[256];
            if (pb_midi_port_name(index, bytes, bytes.Length) == 0) return string.Empty;
            var length = Array.IndexOf(bytes, (byte)0);
            return System.Text.Encoding.UTF8.GetString(bytes, 0, length < 0 ? bytes.Length : length);
        }

        public bool IsPortOnline(int index) => pb_midi_port_online(index) != 0;

        public bool Connect(int index)
        {
            IsConnected = pb_midi_connect(index) != 0;
            return IsConnected;
        }

        public bool TryDequeue(out NativeMidiEvent midiEvent) => pb_midi_poll(out midiEvent) != 0;

        public void Disconnect()
        {
            pb_midi_disconnect();
            IsConnected = false;
        }

        public void Dispose() => Disconnect();
    }
}
