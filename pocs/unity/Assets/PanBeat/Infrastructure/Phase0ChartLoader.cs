using System;
using System.IO;
using PanBeat.Domain;
using UnityEngine;

namespace PanBeat.Infrastructure
{
    [Serializable]
    public sealed class Phase0Chart
    {
        public string schema_version;
        public string chart_id;
        public long duration_us;
        public Phase0ChartNote[] notes;
    }

    [Serializable]
    public sealed class Phase0ChartNote
    {
        public string note_id;
        public long timestamp_us;
        public string technique;
        public string target_id;

        public InputTechnique Technique => technique switch
        {
            "tone" => InputTechnique.Tone,
            "ding" => InputTechnique.Ding,
            "slap" => InputTechnique.Slap,
            _ => throw new InvalidDataException($"Unknown technique: {technique}")
        };
    }

    public static class Phase0ChartLoader
    {
        public static Phase0Chart Load(string path)
        {
            var chart = JsonUtility.FromJson<Phase0Chart>(File.ReadAllText(path));
            if (chart == null || chart.schema_version != "1.0.0" || chart.notes == null)
                throw new InvalidDataException("Invalid Phase 0 chart.");
            foreach (var note in chart.notes) _ = note.Technique;
            return chart;
        }
    }
}
