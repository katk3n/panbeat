using System;
using System.IO;
using System.Threading;
using PanBeat.Infrastructure;

namespace PanBeat.Editor
{
    public static class MidiLifecycleCommand
    {
        public static void Run()
        {
            var arguments = Environment.GetCommandLineArgs();
            var output = Path.GetFullPath(Read(arguments, "-panbeatMidiLifecycleOutput"));
            var duration = int.Parse(Read(arguments, "-panbeatDurationSeconds"));
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException());

            using var adapter = new NativeMidiAdapter();
            using var writer = new StreamWriter(output, false) { AutoFlush = true };
            writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"session\",\"duration_seconds\":{duration},\"queue_capacity\":1024,\"timestamp_domain\":\"core_midi_host_time_microseconds\"}}");
            var started = DateTime.UtcNow;
            var wasPresent = false;
            while ((DateTime.UtcNow - started).TotalSeconds < duration)
            {
                var elapsedUs = (long)(DateTime.UtcNow - started).TotalMilliseconds * 1000;
                var present = adapter.PortCount > 0 && adapter.IsPortOnline(0);
                if (present != wasPresent)
                {
                    if (present)
                    {
                        var name = Escape(adapter.GetPortName(0));
                        var connected = adapter.Connect(0);
                        writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"lifecycle\",\"elapsed_us\":{elapsedUs},\"state\":\"present\",\"port_name\":\"{name}\",\"connected\":{connected.ToString().ToLowerInvariant()}}}");
                    }
                    else
                    {
                        adapter.Disconnect();
                        writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"lifecycle\",\"elapsed_us\":{elapsedUs},\"state\":\"absent\"}}");
                    }
                    wasPresent = present;
                }

                while (adapter.TryDequeue(out var midiEvent))
                    writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"event\",\"elapsed_us\":{elapsedUs},\"callback_timestamp_us\":{midiEvent.TimestampMicroseconds},\"status\":{midiEvent.Status},\"data1\":{midiEvent.Data1},\"data2\":{midiEvent.Data2},\"length\":{midiEvent.Length}}}");
                Thread.Sleep(20);
            }
            writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"summary\",\"dropped_count\":{adapter.DroppedCount}}}");
        }

        private static string Read(string[] arguments, string option)
        {
            var index = Array.IndexOf(arguments, option);
            if (index < 0 || index + 1 >= arguments.Length) throw new ArgumentException($"{option} is required");
            return arguments[index + 1];
        }

        private static string Escape(string value) => value.Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
