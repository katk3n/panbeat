using NUnit.Framework;

namespace PanBeat.Domain.Tests
{
    internal sealed class FakeAudioClock : IAudioClock
    {
        public double DspTimeSeconds { get; set; }
    }

    public sealed class InputTechniqueTests
    {
        [Test]
        public void DomainDefinesExactlyThreePhaseZeroTechniques()
        {
            CollectionAssert.AreEquivalent(
                new[] { "Tone", "Ding", "Slap" },
                System.Enum.GetNames(typeof(InputTechnique)));
        }
    }

    public sealed class DspGameTransportTests
    {
        [Test]
        public void ScheduledLeadClampsSongTimeUntilAudioStart()
        {
            var clock = new FakeAudioClock { DspTimeSeconds = 100 };
            var transport = new DspGameTransport(clock);
            transport.Start(102);
            clock.DspTimeSeconds = 101;
            Assert.That(transport.SongTimeMicroseconds, Is.Zero);
            clock.DspTimeSeconds = 103.25;
            Assert.That(transport.SongTimeMicroseconds, Is.EqualTo(1_250_000));
        }

        [Test]
        public void FrameStallDoesNotRequirePerFrameAccumulation()
        {
            var clock = new FakeAudioClock { DspTimeSeconds = 10 };
            var transport = new DspGameTransport(clock);
            transport.Start(10);
            clock.DspTimeSeconds = 15.5;
            Assert.That(transport.SongTimeMicroseconds, Is.EqualTo(5_500_000));
        }

        [Test]
        public void PauseAndResumeExcludePausedDspDuration()
        {
            var clock = new FakeAudioClock { DspTimeSeconds = 20 };
            var transport = new DspGameTransport(clock);
            transport.Start(20);
            clock.DspTimeSeconds = 22;
            transport.Pause();
            clock.DspTimeSeconds = 30;
            Assert.That(transport.SongTimeMicroseconds, Is.EqualTo(2_000_000));
            transport.Resume();
            clock.DspTimeSeconds = 31;
            Assert.That(transport.SongTimeMicroseconds, Is.EqualTo(3_000_000));
        }
    }
}
