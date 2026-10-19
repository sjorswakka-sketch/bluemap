using System;
using System.Collections;
using UnityEngine;

namespace BlueMapMigration.Phase6
{
    // A reusable presentation service. It does not import save/settings files.
    public sealed class Phase6Audio : MonoBehaviour
    {
        private Phase6Catalog catalog;
        private AudioSource[] effects;
        private AudioSource music, atmosphere;
        private Coroutine fade;
        private string currentMusic = "";
        private float musicVolume = 1, sfxVolume = 1;
        private bool muted;
        private float currentMusicDb, currentAmbienceDb;
        private float[] effectDb;
        public int EffectsStarted { get; private set; }
        public bool MusicWasStarted { get; private set; }
        public bool AmbienceWasStarted { get; private set; }
        public int PoolSize => effects == null ? 0 : effects.Length;
        public bool MusicIsPlaying => music != null && music.isPlaying;

        public void Initialize(Phase6Catalog value)
        {
            if (catalog != null) throw new InvalidOperationException("Audio presentation service already initialized.");
            catalog = value;
            AudioPolicies policies = value.audioPolicies;
            if (policies == null || policies.effectPoolSize != 8 || policies.busyPoolStealIndex != 0)
                throw new InvalidOperationException("Original eight-source sound policy is missing.");
            musicVolume = policies.defaultMusicVolume;
            sfxVolume = policies.defaultSfxVolume;
            muted = policies.defaultMuted;
            effects = new AudioSource[policies.effectPoolSize];
            effectDb = new float[policies.effectPoolSize];
            for (int i = 0; i < effects.Length; i++) effects[i] = Source("Original effects " + i);
            music = Source("Original music");
            atmosphere = Source("Original ambience");
        }
        private AudioSource Source(string sourceName)
        {
            var child = new GameObject(sourceName);
            child.transform.SetParent(transform, false);
            AudioSource source = child.AddComponent<AudioSource>();
            source.playOnAwake = false;
            source.spatialBlend = 0;
            source.ignoreListenerPause = true;
            source.dopplerLevel = 0;
            child.AddComponent<Phase6Gain>();
            return source;
        }
        private void Volume(AudioSource source, float db, float multiplier)
        {
            source.volume = 1;
            source.GetComponent<Phase6Gain>().gain = muted ? 0 : Mathf.Pow(10, db / 20f) * Mathf.Max(catalog.audioPolicies.volumeMinimumLinear, multiplier);
        }
        public AudioClip GetClip(string role, string id) => catalog.GetClip(role, id);
        public bool PlayEffect(string id, float db = 0, float pitch = 1)
        {
            AudioClip clip = catalog.GetClip("effect", id);
            if (clip == null || float.IsNaN(db) || float.IsInfinity(db) || float.IsNaN(pitch) || float.IsInfinity(pitch) || pitch <= 0 || pitch > 3) return false;
            AudioSource chosen = effects[catalog.audioPolicies.busyPoolStealIndex];
            foreach (AudioSource source in effects) if (!source.isPlaying) { chosen = source; break; }
            chosen.Stop();
            chosen.clip = clip;
            chosen.loop = false;
            chosen.pitch = pitch;
            effectDb[Array.IndexOf(effects, chosen)] = db; Volume(chosen, db, sfxVolume);
            chosen.Play();
            EffectsStarted++;
            return true;
        }
        public bool PlayMusic(string id = "forest")
        {
            AudioClip clip = catalog.GetClip("music", id);
            if (clip == null) { id = catalog.audioPolicies.musicFallbackTrack; clip = catalog.GetClip("music", id); }
            if (clip == null) return false;
            if (currentMusic == id && music.isPlaying && catalog.audioPolicies.sameMusicDoesNotRestart) return true;
            if (fade != null) StopCoroutine(fade);
            music.Stop();music.clip = clip;music.loop = true;music.pitch = 1;
            currentMusicDb = catalog.audioPolicies.musicFadeStartDb; Volume(music, currentMusicDb, musicVolume);
            music.Play();currentMusic = id;MusicWasStarted = true;
            fade = StartCoroutine(FadeMusic());
            return true;
        }
        private IEnumerator FadeMusic()
        {
            float elapsed = 0;
            float duration = Mathf.Max(.001f, catalog.audioPolicies.musicFadeSeconds);
            while (elapsed < duration)
            {
                float db = Mathf.Lerp(catalog.audioPolicies.musicFadeStartDb, catalog.audioPolicies.musicDb, elapsed / duration);
                currentMusicDb = db; Volume(music, db, musicVolume);
                elapsed += Time.unscaledDeltaTime;
                yield return null;
            }
            currentMusicDb = catalog.audioPolicies.musicDb; Volume(music, currentMusicDb, musicVolume);
            fade = null;
        }
        public void StopMusic()
        {
            if (fade != null) StopCoroutine(fade);
            fade = null;music.Stop();currentMusic = "";
        }
        public bool PlayAmbience(string cue)
        {
            AmbienceDefinition found = Array.Find(catalog.ambience, value => value.cue == cue);
            if (found == null) return false;
            AudioClip clip = Resources.Load<AudioClip>(found.resourcePath);
            if (clip == null) return false;
            atmosphere.Stop();atmosphere.clip = clip;atmosphere.loop = true;atmosphere.pitch = 1;
            currentAmbienceDb = found.baseDb; Volume(atmosphere, currentAmbienceDb, sfxVolume);atmosphere.Play();AmbienceWasStarted = true;
            return true;
        }
        public void SetVolumes(float musicLevel, float effectsLevel, bool mute)
        {
            musicVolume = Mathf.Clamp01(musicLevel);sfxVolume = Mathf.Clamp01(effectsLevel);muted = mute;
            Volume(music, currentMusicDb, musicVolume);
            for (int i = 0; i < effects.Length; i++) Volume(effects[i], effectDb[i], sfxVolume);
            Volume(atmosphere, currentAmbienceDb, sfxVolume);
        }
        public void StopAmbience() { atmosphere.Stop(); }
    }
}
