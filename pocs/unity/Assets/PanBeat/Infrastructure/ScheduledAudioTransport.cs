using System;
using PanBeat.Domain;
using UnityEngine;

namespace PanBeat.Infrastructure
{
    public sealed class ScheduledAudioTransport
    {
        public const double DefaultStartLeadSeconds = 0.1;
        private readonly AudioSource source;
        private readonly IAudioClock clock;

        public ScheduledAudioTransport(AudioSource source, IAudioClock clock)
        {
            this.source = source ? source : throw new ArgumentNullException(nameof(source));
            this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
            Transport = new DspGameTransport(clock);
        }

        public IGameTransport Transport { get; }

        public void Schedule(AudioClip clip, double startLeadSeconds = DefaultStartLeadSeconds)
        {
            if (!clip) throw new ArgumentNullException(nameof(clip));
            if (startLeadSeconds < 0) throw new ArgumentOutOfRangeException(nameof(startLeadSeconds));
            source.clip = clip;
            var scheduledTime = clock.DspTimeSeconds + startLeadSeconds;
            source.PlayScheduled(scheduledTime);
            Transport.Start(scheduledTime);
        }

        public void Pause()
        {
            source.Pause();
            Transport.Pause();
        }

        public void Resume()
        {
            source.UnPause();
            Transport.Resume();
        }
    }
}
