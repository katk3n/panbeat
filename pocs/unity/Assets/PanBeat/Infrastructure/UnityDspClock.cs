using PanBeat.Domain;
using UnityEngine;

namespace PanBeat.Infrastructure
{
    public sealed class UnityDspClock : IAudioClock
    {
        public double DspTimeSeconds => AudioSettings.dspTime;
    }
}
