using System;
using System.IO;
using System.Linq;
using PanBeat.Domain;
using PanBeat.Infrastructure;
using PanBeat.Presentation;
using UnityEngine;

namespace PanBeat.Editor
{
    public static class ScreenshotCommand
    {
        public static void Capture()
        {
            var arguments = Environment.GetCommandLineArgs();
            var option = Array.IndexOf(arguments, "-panbeatScreenshotOutput");
            if (option < 0 || option + 1 >= arguments.Length) throw new ArgumentException("-panbeatScreenshotOutput is required");
            var output = Path.GetFullPath(arguments[option + 1]);
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException());
            var repositoryRoot = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var chart = Phase0ChartLoader.Load(Path.Combine(repositoryRoot, "shared/fixtures/test-pack/chart.json"));
            if (chart.duration_us != 30_000_000 || !new[] { InputTechnique.Tone, InputTechnique.Ding, InputTechnique.Slap }.All(
                    technique => chart.notes.Any(note => note.Technique == technique)))
                throw new InvalidDataException("30-second chart does not cover all Phase 0 techniques.");
            var texture = RadialPreviewRasterizer.Render();
            File.WriteAllBytes(output, texture.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(texture);
        }
    }
}
