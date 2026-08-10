using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using PanBeat.Domain;
using UnityEngine;

namespace PanBeat.Editor
{
    [Serializable] internal sealed class SliceInputDocument { public SliceCase[] cases; }
    [Serializable] internal sealed class SliceCase { public string case_id; public long note_timestamp_us; public long input_timestamp_us; public string technique; public string target_id; }

    public static class UnitySliceCommand
    {
        public static void Run()
        {
            var args = Environment.GetCommandLineArgs();
            var index = Array.IndexOf(args, "-panbeatSliceOutputDir");
            if (index < 0 || index + 1 >= args.Length) throw new ArgumentException("-panbeatSliceOutputDir is required");
            var output = Path.GetFullPath(args[index + 1]);
            Directory.CreateDirectory(output);
            var root = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var inputPath = Path.Combine(root, "shared/fixtures/test-pack/golden-inputs.json");
            var document = JsonUtility.FromJson<SliceInputDocument>(File.ReadAllText(inputPath));
            var judgements = BuildJudgements(document);
            var scenarios = new[] { "60hz", "120hz", "frame-stall" };
            foreach (var scenario in scenarios) File.WriteAllText(Path.Combine(output, $"judgements-{scenario}.json"), judgements);
            File.WriteAllText(Path.Combine(output, "performance-log.json"),
                "{\n  \"schema_version\": \"1.0.0\",\n  \"engine\": \"unity\",\n  \"input_offset_us\": 0,\n  \"audio_offset_us\": 0,\n  \"scenarios\": [\"60hz\", \"120hz\", \"frame-stall\"]\n}\n");
            WriteManifest(root, output, scenarios);
        }

        private static string BuildJudgements(SliceInputDocument document)
        {
            var engine = new JudgementEngine();
            var builder = new StringBuilder("[\n");
            for (var index = 0; index < document.cases.Length; index++)
            {
                var item = document.cases[index];
                var hasInput = item.case_id != "no-input-miss";
                var outcome = engine.Judge(item.note_timestamp_us, hasInput ? item.input_timestamp_us : null);
                builder.Append("  {\"schema_version\":\"1.0.0\",\"record_id\":\"").Append(item.case_id)
                    .Append("\",\"note_id\":\"").Append(item.case_id).Append("\",\"note_timestamp_us\":").Append(item.note_timestamp_us)
                    .Append(",\"clock_domain\":\"song_time\",\"technique\":\"").Append(item.technique)
                    .Append("\",\"target_id\":\"").Append(item.target_id).Append("\",\"judgement\":\"")
                    .Append(outcome.Judgement.ToString().ToLowerInvariant()).Append('"');
                if (outcome.InputTimestampUs.HasValue)
                    builder.Append(",\"input_event_id\":\"").Append(item.case_id).Append(":input\",\"input_timestamp_us\":")
                        .Append(outcome.InputTimestampUs.Value).Append(",\"delta_us\":").Append(outcome.DeltaUs.Value);
                builder.Append(index + 1 == document.cases.Length ? "}\n" : "},\n");
            }
            return builder.Append("]\n").ToString();
        }

        private static void WriteManifest(string root, string output, string[] scenarios)
        {
            var builder = new StringBuilder();
            builder.Append("{\n  \"schema_version\": \"1.0.0\",\n  \"run_id\": \"unity-u05\",\n  \"engine\": \"unity\",\n  \"started_at\": \"")
                .Append(DateTime.UtcNow.ToString("O")).Append("\",\n  \"source_revision\": \"working-tree\",\n  \"build_type\": \"editor\",\n  \"clock_domains\": [\"song_time\", \"unity_dsp\"],\n  \"inputs\": [\n")
                .Append(Artifact(root, "shared/fixtures/test-pack/golden-inputs.json")).Append(",\n")
                .Append(Artifact(root, "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json")).Append(",\n")
                .Append(Artifact(root, "artifacts/raw/unity-u03/lifecycle-verified.jsonl")).Append("\n  ],\n  \"outputs\": [\n");
            for (var i = 0; i < scenarios.Length; i++)
            {
                var path = $"artifacts/raw/unity-u05/judgements-{scenarios[i]}.json";
                builder.Append(Artifact(root, path)).Append(",\n");
            }
            builder.Append(Artifact(root, "artifacts/raw/unity-u05/performance-log.json")).Append("\n  ]\n}\n");
            File.WriteAllText(Path.Combine(output, "run-manifest.json"), builder.ToString());
        }

        private static string Artifact(string root, string relative)
        {
            using var sha = SHA256.Create();
            var hash = BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(Path.Combine(root, relative)))).Replace("-", "").ToLowerInvariant();
            return $"    {{\"path\":\"{relative}\",\"sha256\":\"{hash}\"}}";
        }
    }
}
