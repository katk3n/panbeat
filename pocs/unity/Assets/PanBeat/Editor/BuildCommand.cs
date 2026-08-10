using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;

namespace PanBeat.Editor
{
    public static class BuildCommand
    {
        public static void BuildMac()
        {
            BuildMac(BuildOptions.Development);
        }

        public static void BuildMacRelease()
        {
            BuildMac(BuildOptions.None);
        }

        private static void BuildMac(BuildOptions options)
        {
            var arguments = Environment.GetCommandLineArgs();
            var optionIndex = Array.IndexOf(arguments, "-panbeatBuildPath");
            if (optionIndex < 0 || optionIndex + 1 >= arguments.Length)
                throw new ArgumentException("-panbeatBuildPath is required");

            var output = Path.GetFullPath(arguments[optionIndex + 1]);
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? throw new InvalidOperationException("Build output has no parent directory."));
            var scenes = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path).ToArray();
            if (scenes.Length == 0) throw new InvalidOperationException("No enabled build scenes.");

            PlayerSettings.companyName = "PanBeat";
            PlayerSettings.productName = "PanBeat";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Standalone, "local.panbeat.phase0.unity");

            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = output,
                target = BuildTarget.StandaloneOSX,
                options = options
            });
            if (report.summary.result != BuildResult.Succeeded)
                throw new InvalidOperationException($"macOS build failed: {report.summary.result}");
        }
    }
}
