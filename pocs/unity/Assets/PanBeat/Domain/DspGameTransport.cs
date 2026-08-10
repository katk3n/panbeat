using System;

namespace PanBeat.Domain
{
    public sealed class DspGameTransport : IGameTransport
    {
        private readonly IAudioClock clock;
        private double startDspTime;
        private double pausedAtDspTime;
        private long pausedSongTimeMicroseconds;

        public DspGameTransport(IAudioClock clock)
        {
            this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        }

        public bool IsRunning { get; private set; }
        public bool IsPaused { get; private set; }

        public long SongTimeMicroseconds
        {
            get
            {
                if (!IsRunning) return 0;
                if (IsPaused) return pausedSongTimeMicroseconds;
                return Math.Max(0, (long)Math.Round((clock.DspTimeSeconds - startDspTime) * 1_000_000.0));
            }
        }

        public void Start(double scheduledDspTimeSeconds)
        {
            if (!double.IsFinite(scheduledDspTimeSeconds)) throw new ArgumentOutOfRangeException(nameof(scheduledDspTimeSeconds));
            startDspTime = scheduledDspTimeSeconds;
            pausedAtDspTime = 0;
            pausedSongTimeMicroseconds = 0;
            IsRunning = true;
            IsPaused = false;
        }

        public void Pause()
        {
            if (!IsRunning || IsPaused) return;
            pausedSongTimeMicroseconds = SongTimeMicroseconds;
            pausedAtDspTime = clock.DspTimeSeconds;
            IsPaused = true;
        }

        public void Resume()
        {
            if (!IsRunning || !IsPaused) return;
            startDspTime += clock.DspTimeSeconds - pausedAtDspTime;
            IsPaused = false;
        }
    }
}
