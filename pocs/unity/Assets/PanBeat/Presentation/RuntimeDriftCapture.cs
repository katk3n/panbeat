using System;
using System.Collections;
using System.Globalization;
using System.IO;
using UnityEngine;

namespace PanBeat.Presentation
{
    public sealed class RuntimeDriftCapture : MonoBehaviour
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void StartWhenRequested()
        {
            var arguments = Environment.GetCommandLineArgs();
            if (Array.IndexOf(arguments, "-panbeatDriftOutput") >= 0)
                new GameObject("PanBeat Release Drift Capture").AddComponent<RuntimeDriftCapture>();
        }

        private IEnumerator Start()
        {
            var arguments = Environment.GetCommandLineArgs();
            var output = Path.GetFullPath(Read(arguments, "-panbeatDriftOutput"));
            var audioPath = Path.GetFullPath(Read(arguments, "-panbeatAudioPath"));
            var duration = double.Parse(Read(arguments, "-panbeatDurationSeconds"), CultureInfo.InvariantCulture);
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException());
            var clip = LoadPcm16MonoWav(audioPath);
            var source = gameObject.AddComponent<AudioSource>();
            source.clip = clip;
            source.loop = true;
            var scheduledDsp = AudioSettings.dspTime + 0.5;
            source.PlayScheduled(scheduledDsp);
            while (AudioSettings.dspTime < scheduledDsp + 0.2) yield return null;

            using var writer = new StreamWriter(output, false) { AutoFlush = true };
            writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"session\",\"engine\":\"unity\",\"build_type\":\"release\",\"duration_seconds\":{duration.ToString(CultureInfo.InvariantCulture)},\"clip_samples\":{clip.samples},\"clip_sample_rate_hz\":{clip.frequency},\"output_sample_rate_hz\":{AudioSettings.outputSampleRate},\"clock_domain\":\"unity_dsp_and_audio_playhead\"}}");
            var previousSample = source.timeSamples;
            long loopCount = 0;
            var baselineSet = false;
            double baselineDelta = 0;
            var nextSampleDsp = AudioSettings.dspTime;
            var sequence = 0;
            while (AudioSettings.dspTime - scheduledDsp <= duration)
            {
                if (AudioSettings.dspTime < nextSampleDsp) { yield return null; continue; }
                var currentSample = source.timeSamples;
                if (currentSample < previousSample - clip.samples / 2) loopCount++;
                previousSample = currentSample;
                var actualSamples = loopCount * (long)clip.samples + currentSample;
                var expectedSamples = (AudioSettings.dspTime - scheduledDsp) * clip.frequency;
                var delta = actualSamples - expectedSamples;
                if (!baselineSet) { baselineDelta = delta; baselineSet = true; }
                var driftUs = (long)Math.Round((delta - baselineDelta) / clip.frequency * 1_000_000.0);
                writer.WriteLine($"{{\"schema_version\":\"1.0.0\",\"record_type\":\"sample\",\"sequence\":{sequence++},\"dsp_song_time_us\":{(long)Math.Round((AudioSettings.dspTime-scheduledDsp)*1_000_000.0)},\"audio_unwrapped_samples\":{actualSamples},\"drift_us\":{driftUs}}}");
                nextSampleDsp += 0.1;
            }
            source.Stop();
            Application.Quit(0);
        }

        private static AudioClip LoadPcm16MonoWav(string file)
        {
            var bytes = File.ReadAllBytes(file);
            if (bytes.Length < 44 || BitConverter.ToInt16(bytes, 22) != 1 || BitConverter.ToInt16(bytes, 34) != 16)
                throw new InvalidDataException("Expected a PCM16 mono WAV fixture.");
            var sampleRate = BitConverter.ToInt32(bytes, 24);
            var sampleCount = (bytes.Length - 44) / 2;
            var samples = new float[sampleCount];
            for (var index = 0; index < sampleCount; index++) samples[index] = BitConverter.ToInt16(bytes, 44 + index * 2) / 32768f;
            var clip = AudioClip.Create("PanBeat 30s drift fixture", sampleCount, 1, sampleRate, false);
            clip.SetData(samples, 0);
            return clip;
        }

        private static string Read(string[] arguments, string option)
        {
            var index = Array.IndexOf(arguments, option);
            if (index < 0 || index + 1 >= arguments.Length) throw new ArgumentException($"{option} is required");
            return arguments[index + 1];
        }
    }
}
