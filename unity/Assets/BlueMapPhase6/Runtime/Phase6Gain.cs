using UnityEngine;

namespace BlueMapMigration.Phase6
{
    // AudioSource.volume clamps at one. The source game accepts positive dB,
    // so keep its linear gain in a source-local audio filter instead.
    public sealed class Phase6Gain : MonoBehaviour
    {
        public volatile float gain = 1;
        private void OnAudioFilterRead(float[] data, int channels)
        {
            float multiplier = gain;
            for (int i = 0; i < data.Length; i++) data[i] *= multiplier;
        }
    }
}
