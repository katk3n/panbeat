using NUnit.Framework;
using PanBeat.Infrastructure;

namespace PanBeat.Domain.Tests
{
    public sealed class NativeMidiAdapterTests
    {
        [SetUp]
        public void Reset() => NativeMidiAdapter.pb_midi_reset_queue();

        [Test]
        public void NativeQueuePreservesTimestampAndRawMessage()
        {
            NativeMidiAdapter.pb_midi_test_inject(123456, 0x90, 50, 127);
            using var adapter = new NativeMidiAdapter();
            Assert.That(adapter.TryDequeue(out var midiEvent), Is.True);
            Assert.That(midiEvent.TimestampMicroseconds, Is.EqualTo(123456));
            Assert.That(new[] { midiEvent.Status, midiEvent.Data1, midiEvent.Data2 }, Is.EqualTo(new byte[] { 0x90, 50, 127 }));
        }

        [Test]
        public void QueueOverflowIsCountedAndNotSilent()
        {
            for (var index = 0; index < 1100; index++)
                NativeMidiAdapter.pb_midi_test_inject((ulong)index, 0x90, 50, 100);
            using var adapter = new NativeMidiAdapter();
            Assert.That(adapter.DroppedCount, Is.GreaterThan(0));
        }
    }
}
