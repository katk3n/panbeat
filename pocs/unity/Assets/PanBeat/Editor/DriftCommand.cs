using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using UnityEditor;
using UnityEngine;

namespace PanBeat.Editor
{
    public static class DriftCommand
    {
        public static void Run()
        {
            var arguments = Environment.GetCommandLineArgs();
            var duration = ReadDouble(arguments, "-panbeatDurationSeconds", 30);
            var interval = ReadDouble(arguments, "-panbeatSampleIntervalSeconds", 0.1);
            var output = Path.GetFullPath(ReadString(arguments, "-panbeatDriftOutput"));
            var manifest = Path.GetFullPath(ReadString(arguments, "-panbeatManifestOutput"));
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException());
            Directory.CreateDirectory(Path.GetDirectoryName(manifest) ?? throw new InvalidOperationException());

            AudioSettings.GetDSPBufferSize(out var bufferLength, out var bufferCount);
            var dspOrigin = AudioSettings.dspTime;
            var stopwatch = Stopwatch.StartNew();
            using (var writer = new StreamWriter(output, false))
            {
                var sequence = 0;
                while (stopwatch.Elapsed.TotalSeconds <= duration)
                {
                    var monotonicUs = (long)Math.Round(stopwatch.Elapsed.TotalSeconds * 1_000_000);
                    var dspUs = (long)Math.Round((AudioSettings.dspTime - dspOrigin) * 1_000_000);
                    writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"sequence\":{sequence++},\"monotonic_elapsed_us\":{monotonicUs},\"dsp_elapsed_us\":{dspUs},\"drift_us\":{dspUs - monotonicUs}}}");
                    writer.Flush();
                    Thread.Sleep(TimeSpan.FromSeconds(interval));
                }
            }

            File.WriteAllText(manifest,
                "{\n" +
                "  \"schema_version\": \"1.0.0\",\n" +
                "  \"engine\": \"unity\",\n" +
                $"  \"engine_version\": \"{Application.unityVersion}\",\n" +
                $"  \"duration_seconds\": {duration.ToString(CultureInfo.InvariantCulture)},\n" +
                $"  \"sample_interval_seconds\": {interval.ToString(CultureInfo.InvariantCulture)},\n" +
                $"  \"audio_sample_rate_hz\": {AudioSettings.outputSampleRate},\n" +
                $"  \"dsp_buffer_length_samples\": {bufferLength},\n" +
                $"  \"dsp_buffer_count\": {bufferCount},\n" +
                "  \"clock_domain\": \"unity_audio_settings_dsp_time\"\n" +
                "}\n");
        }

        private static string ReadString(string[] arguments, string option)
        {
            var index = Array.IndexOf(arguments, option);
            if (index < 0 || index + 1 >= arguments.Length) throw new ArgumentException($"{option} is required");
            return arguments[index + 1];
        }

        private static double ReadDouble(string[] arguments, string option, double fallback)
        {
            var index = Array.IndexOf(arguments, option);
            return index < 0 ? fallback : double.Parse(arguments[index + 1], CultureInfo.InvariantCulture);
        }
    }
}
