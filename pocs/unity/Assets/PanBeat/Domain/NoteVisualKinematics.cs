using System;

namespace PanBeat.Domain
{
    public readonly struct VisualPose
    {
        public VisualPose(double radius, double angleDegrees, double progress)
        {
            Radius = radius;
            AngleDegrees = angleDegrees;
            Progress = progress;
        }
        public double Radius { get; }
        public double AngleDegrees { get; }
        public double Progress { get; }
    }

    public static class NoteVisualKinematics
    {
        public const double SpawnRadius = 0.45;
        public const double OuterHitRadius = 0.85;

        public static VisualPose Evaluate(InputTechnique technique, double targetAngleDegrees,
            long spawnTimeUs, long hitTimeUs, long songTimeUs)
        {
            if (hitTimeUs <= spawnTimeUs) throw new ArgumentOutOfRangeException(nameof(hitTimeUs));
            var progress = Math.Clamp((songTimeUs - spawnTimeUs) / (double)(hitTimeUs - spawnTimeUs), 0, 1);
            var radius = technique switch
            {
                InputTechnique.Ding => SpawnRadius * (1 - progress),
                InputTechnique.Tone => SpawnRadius + (OuterHitRadius - SpawnRadius) * progress,
                InputTechnique.Slap => SpawnRadius + (OuterHitRadius - SpawnRadius) * progress,
                _ => throw new ArgumentOutOfRangeException(nameof(technique))
            };
            return new VisualPose(radius, targetAngleDegrees, progress);
        }
    }
}
