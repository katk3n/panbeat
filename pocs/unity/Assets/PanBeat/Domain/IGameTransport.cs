namespace PanBeat.Domain
{
    public interface IGameTransport
    {
        bool IsRunning { get; }
        bool IsPaused { get; }
        long SongTimeMicroseconds { get; }
        void Start(double scheduledDspTimeSeconds);
        void Pause();
        void Resume();
    }
}
