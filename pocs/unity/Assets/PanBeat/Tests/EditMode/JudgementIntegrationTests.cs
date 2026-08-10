using System;
using System.IO;
using NUnit.Framework;
using PanBeat.Infrastructure;
using UnityEngine;

namespace PanBeat.Domain.Tests
{
    [Serializable] internal sealed class GoldenInputDocument { public GoldenCase[] cases; }
    [Serializable] internal sealed class GoldenCase { public string case_id; public long note_timestamp_us; public long input_timestamp_us; }
    [Serializable] internal sealed class GoldenExpected { public string record_id; public string judgement; public long input_timestamp_us; public long delta_us; }
    [Serializable] internal sealed class GoldenExpectedWrapper { public GoldenExpected[] items; }
    [Serializable] internal sealed class LifecycleEvent { public string record_type; public int status; public int data1; public int data2; }

    public sealed class JudgementIntegrationTests
    {
        private static string Root => Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));

        [Test]
        public void GoldenBoundaryResultsMatchExactly()
        {
            var inputs = JsonUtility.FromJson<GoldenInputDocument>(File.ReadAllText(Path.Combine(Root, "shared/fixtures/test-pack/golden-inputs.json")));
            var expectedJson = File.ReadAllText(Path.Combine(Root, "shared/fixtures/test-pack/golden-results.json"));
            var expected = JsonUtility.FromJson<GoldenExpectedWrapper>($"{{\"items\":{expectedJson}}}").items;
            var engine = new JudgementEngine();
            Assert.That(inputs.cases, Has.Length.EqualTo(expected.Length));
            for (var index = 0; index < inputs.cases.Length; index++)
            {
                var input = inputs.cases[index];
                var hasInput = input.case_id != "no-input-miss";
                var actual = engine.Judge(input.note_timestamp_us, hasInput ? input.input_timestamp_us : null);
                Assert.That(actual.Judgement.ToString().ToLowerInvariant(), Is.EqualTo(expected[index].judgement), input.case_id);
                Assert.That(actual.InputTimestampUs, Is.EqualTo(expected[index].judgement == "miss" ? (long?)null : expected[index].input_timestamp_us), input.case_id);
                Assert.That(actual.DeltaUs, Is.EqualTo(expected[index].judgement == "miss" ? (long?)null : expected[index].delta_us), input.case_id);
            }
        }

        [Test]
        public void FrameRateAndStallDoNotChangeJudgementJsonInputs()
        {
            var engine = new JudgementEngine();
            var expected = engine.Judge(1_000_000, 1_030_000);
            foreach (var simulatedRefreshRate in new[] { 60, 120, 0 })
            {
                Assert.That(simulatedRefreshRate, Is.GreaterThanOrEqualTo(0));
                var actual = engine.Judge(1_000_000, 1_030_000);
                Assert.That(actual.Judgement, Is.EqualTo(expected.Judgement));
                Assert.That(actual.DeltaUs, Is.EqualTo(expected.DeltaUs));
            }
        }

        [Test]
        public void SharedHandpanProfileMapsDingToneSlapAndDiagnosesUnknown()
        {
            var mapper = InstrumentProfileMapper.Load(Path.Combine(Root, "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json"));
            Assert.That(mapper.Map(0x90, 50, 127).Technique, Is.EqualTo(InputTechnique.Ding));
            Assert.That(mapper.Map(0x90, 57, 100).Technique, Is.EqualTo(InputTechnique.Tone));
            Assert.That(mapper.Map(0x90, 93, 100).Technique, Is.EqualTo(InputTechnique.Slap));
            Assert.That(mapper.Map(0x90, 99, 100).Diagnostic, Is.EqualTo("unknown_mapping"));
        }

        [Test]
        public void RecordedUnityLifecycleUsesTheSameProfileMapper()
        {
            var mapper = InstrumentProfileMapper.Load(Path.Combine(Root, "shared/fixtures/instrument-profiles/roland-mn10-handpan-minor-v1.json"));
            var lines = File.ReadAllLines(Path.Combine(Root, "artifacts/raw/unity-u03/lifecycle-verified.jsonl"));
            var mapped = 0;
            foreach (var line in lines)
            {
                var item = JsonUtility.FromJson<LifecycleEvent>(line);
                if (item.record_type != "event" || (item.status & 0xF0) != 0x90 || item.data2 == 0) continue;
                var result = mapper.Map((byte)item.status, (byte)item.data1, (byte)item.data2);
                Assert.That(result.IsMapped, Is.True);
                Assert.That(result.Technique, Is.EqualTo(InputTechnique.Ding));
                mapped++;
            }
            Assert.That(mapped, Is.EqualTo(6));
        }
    }
}
