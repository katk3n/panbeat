using System;
using System.Collections;
using System.IO;
using PanBeat.Infrastructure;
using UnityEngine;

namespace PanBeat.Presentation
{
    public sealed class RuntimeMidiCapture : MonoBehaviour
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void StartWhenRequested()
        {
            var arguments = Environment.GetCommandLineArgs();
            if (Array.IndexOf(arguments, "-panbeatE02Output") >= 0)
                new GameObject("PanBeat E02 MIDI Capture").AddComponent<RuntimeMidiCapture>();
        }

        private IEnumerator Start()
        {
            var arguments = Environment.GetCommandLineArgs();
            var output = Path.GetFullPath(Read(arguments, "-panbeatE02Output"));
            var duration = int.Parse(Read(arguments, "-panbeatDurationSeconds"));
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException());
            using var adapter = new NativeMidiAdapter();
            using var writer = new StreamWriter(output, false) { AutoFlush = true };
            writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"session\",\"duration_seconds\":{duration},\"build_type\":\"release\",\"timestamp_domain\":\"core_midi_host_time_microseconds\"}}");
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
                yield return new WaitForSecondsRealtime(0.02f);
            }
            writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"summary\",\"dropped_count\":{adapter.DroppedCount}}}");
            Application.Quit(0);
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
