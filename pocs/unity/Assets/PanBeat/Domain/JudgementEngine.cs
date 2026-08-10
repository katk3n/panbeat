using System;

namespace PanBeat.Domain
{
    public enum Judgement { Perfect, Great, Good, Miss }

    public readonly struct JudgementOutcome
    {
        public JudgementOutcome(Judgement judgement, long? inputTimestampUs, long? deltaUs)
        {
            Judgement = judgement;
            InputTimestampUs = inputTimestampUs;
            DeltaUs = deltaUs;
        }
        public Judgement Judgement { get; }
        public long? InputTimestampUs { get; }
        public long? DeltaUs { get; }
    }

    public sealed class JudgementEngine
    {
        public JudgementEngine(long perfectUs = 30_000, long greatUs = 60_000, long goodUs = 100_000)
        {
            PerfectUs = perfectUs;
            GreatUs = greatUs;
            GoodUs = goodUs;
        }
        public long PerfectUs { get; }
        public long GreatUs { get; }
        public long GoodUs { get; }

        public JudgementOutcome Judge(long noteTimestampUs, long? inputTimestampUs)
        {
            if (!inputTimestampUs.HasValue) return new JudgementOutcome(Judgement.Miss, null, null);
            var delta = inputTimestampUs.Value - noteTimestampUs;
            var absolute = Math.Abs(delta);
            if (absolute > GoodUs) return new JudgementOutcome(Judgement.Miss, null, null);
            var judgement = absolute <= PerfectUs ? Judgement.Perfect : absolute <= GreatUs ? Judgement.Great : Judgement.Good;
            return new JudgementOutcome(judgement, inputTimestampUs, delta);
        }
    }
}
