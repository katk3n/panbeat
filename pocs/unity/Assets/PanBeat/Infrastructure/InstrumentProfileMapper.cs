using System;
using System.IO;
using PanBeat.Domain;
using UnityEngine;

namespace PanBeat.Infrastructure
{
    [Serializable] public sealed class UnityInstrumentProfile { public string schema_version; public string profile_id; public UnityProfileMapping[] mappings; }
    [Serializable] public sealed class UnityProfileMapping { public int channel_wire; public int note; public int velocity_min; public int velocity_max; public string technique; public string target_id; }

    public readonly struct MappedInput
    {
        public MappedInput(bool mapped, InputTechnique technique, string targetId, int velocity, string diagnostic)
        { IsMapped = mapped; Technique = technique; TargetId = targetId; Velocity = velocity; Diagnostic = diagnostic; }
        public bool IsMapped { get; }
        public InputTechnique Technique { get; }
        public string TargetId { get; }
        public int Velocity { get; }
        public string Diagnostic { get; }
    }

    public sealed class InstrumentProfileMapper
    {
        private readonly UnityInstrumentProfile profile;
        public InstrumentProfileMapper(UnityInstrumentProfile profile) => this.profile = profile ?? throw new ArgumentNullException(nameof(profile));
        public static InstrumentProfileMapper Load(string path) => new InstrumentProfileMapper(JsonUtility.FromJson<UnityInstrumentProfile>(File.ReadAllText(path)));

        public MappedInput Map(byte status, byte data1, byte data2)
        {
            if ((status & 0xF0) != 0x90 || data2 == 0) return new MappedInput(false, default, null, 0, "non_trigger_message");
            var channel = status & 0x0F;
            foreach (var mapping in profile.mappings)
                if (mapping.channel_wire == channel && mapping.note == data1 && data2 >= mapping.velocity_min && data2 <= mapping.velocity_max)
                    return new MappedInput(true, Parse(mapping.technique), mapping.target_id, data2, null);
            return new MappedInput(false, default, null, data2, "unknown_mapping");
        }

        private static InputTechnique Parse(string value) => value switch
        { "tone" => InputTechnique.Tone, "ding" => InputTechnique.Ding, "slap" => InputTechnique.Slap, _ => throw new InvalidDataException(value) };
    }
}
