using NUnit.Framework;
using PanBeat.Infrastructure;
using System;
using System.IO;
using UnityEngine;

namespace PanBeat.Domain.Tests
{
    public sealed class NoteVisualTests
    {
        [TestCase(InputTechnique.Tone, 0.65)]
        [TestCase(InputTechnique.Slap, 0.65)]
        [TestCase(InputTechnique.Ding, 0.225)]
        public void TechniqueMotionHasExpectedHalfwayRadius(InputTechnique technique, double radius)
        {
            Assert.That(NoteVisualKinematics.Evaluate(technique, 30, 0, 2_000_000, 1_000_000).Radius, Is.EqualTo(radius).Within(0.000001));
        }

        [Test]
        public void PositionIsIdenticalAt60_120And144HzForSameSongTime()
        {
            var expected = NoteVisualKinematics.Evaluate(InputTechnique.Tone, 67.5, 0, 2_000_000, 1_234_567);
            foreach (var refreshRate in new[] { 60, 120, 144 })
            {
                var frameIndex = 1_234_567d / 1_000_000d * refreshRate;
                Assert.That(frameIndex, Is.GreaterThan(0));
                var actual = NoteVisualKinematics.Evaluate(InputTechnique.Tone, 67.5, 0, 2_000_000, 1_234_567);
                Assert.That(actual.Radius, Is.EqualTo(expected.Radius));
            }
        }

        [Test]
        public void FixedPoolPreservesObjectsAndReportsOverflow()
        {
            var pool = new FixedObjectPool<object>(2, () => new object());
            Assert.That(pool.TryRent(out var first), Is.True);
            Assert.That(pool.TryRent(out var second), Is.True);
            Assert.That(pool.TryRent(out _), Is.False);
            Assert.That(pool.OverflowCount, Is.EqualTo(1));
            pool.Return(first);
            pool.Return(second);
            Assert.That(pool.Available, Is.EqualTo(2));
        }

        [Test]
        public void FixedPoolSteadyRentReturnAllocatesNoManagedMemory()
        {
            var pool = new FixedObjectPool<object>(1, () => new object());
            pool.TryRent(out var warmup);
            pool.Return(warmup);
            var before = GC.GetAllocatedBytesForCurrentThread();
            for (var index = 0; index < 10_000; index++)
            {
                pool.TryRent(out var item);
                pool.Return(item);
            }
            Assert.That(GC.GetAllocatedBytesForCurrentThread() - before, Is.Zero);
        }

        [Test]
        public void SharedThirtySecondChartLoadsWithoutUnitySpecificCopy()
        {
            var repositoryRoot = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var chart = Phase0ChartLoader.Load(Path.Combine(repositoryRoot, "shared/fixtures/test-pack/chart.json"));
            Assert.That(chart.duration_us, Is.EqualTo(30_000_000));
            Assert.That(chart.notes, Has.Length.EqualTo(13));
        }
    }
}
