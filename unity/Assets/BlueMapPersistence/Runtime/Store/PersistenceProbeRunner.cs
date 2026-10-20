using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using UnityEngine;

namespace BlueMapMigration.Persistence
{
    public static class PersistenceProbeRunner
    {
        [Serializable] public sealed class Result
        {
            public int schemaVersion=1;
            public bool success,gameSaveAccessed=false;
            public BuildIdentity identity;
            public Phase2Probe.Check[] checks;
        }
        public static PersistenceCoordinator Fixture {get;private set;}
        public static Result Run(BuildIdentity identity,string output,PlayerInputSource input)
        {
            var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool passed){checks.Add(new Phase2Probe.Check{name=name,passed=passed});if(!passed)Debug.LogError("Persistence check failed: "+name);}
            var repository=FoundationWorldRepository.LoadRequired();
            LegacySaveChecks.Verify(repository,Check);LegacySettingsChecks.Verify(Check,repository);
            // Keep the synthetic path short enough for the pinned Windows Mono file APIs.
            string area=Path.Combine(output,"pf");Directory.CreateDirectory(area);
            string source=Path.Combine(area,"g"),target=Path.Combine(area,"u");Directory.CreateDirectory(source);
            byte[] raw=PersistencePaths.Utf8.GetBytes("{\"map\":\"village\",\"pos\":[385.125,801.75],\"coins\":1234567890123,\"inventory\":{\"grape\":11,\"future_material\":27},\"flags\":{\"future_quest\":false},\"future\":{\"kind\":\"crop\",\"message\":\"🌱 behouden\"}}");
            File.WriteAllBytes(Path.Combine(source,"savegame.json"),raw);
            File.WriteAllBytes(Path.Combine(source,"settings.cfg"),PersistencePaths.Utf8.GetBytes("[audio]\nmusic=0.35\nsfx=0.7\nmuted=false\n[taal]\nlocale=\"nl\"\n[future]\nkind=\"vineyard\"\n"));
            File.WriteAllBytes(Path.Combine(source,"meta.cfg"),PersistencePaths.Utf8.GetBytes("[achievements]\nfuture_badge=false\n"));
            File.WriteAllBytes(Path.Combine(source,"ng_plus.cfg"),PersistencePaths.Utf8.GetBytes("[ng]\ncompleted=true\nrounds=2\nweapon=\"wood\"\n"));
            // Unknown cosmetic syntax is retained without being executed or blocking the adventure.
            File.WriteAllBytes(Path.Combine(source,"controls.cfg"),PersistencePaths.Utf8.GetBytes("[future]\nunsafe=Object(\"Node\",\"script\":\"untrusted\")\n"));
            var before=LegacySourceSet.Read(source);var hashes=before.CopyFiles().ToDictionary(p=>p.Key,p=>PersistencePaths.Hash(p.Value));
            foreach(string name in before.FileNames)File.SetAttributes(Path.Combine(source,name),FileAttributes.ReadOnly);
            var coordinator=new PersistenceCoordinator(repository,input,target){SourceDirectory=source};
            bool imported=coordinator.ImportSource(source);Check("persistence_fixture_import_opens",imported);
            if(!imported)throw new InvalidOperationException("Synthetic profile import failed: "+coordinator.Status);
            var first=coordinator.Current;var store=new PersistenceStore(target);
            Check("persistence_import_keeps_adventure",first.Snapshot.State.Require("coins").AsInt64()==1234567890123&&first.Snapshot.State.Require("inventory").Require("future_material").AsInt64()==27);
            var loaded=store.Load(first.ProfileId);
            Check("persistence_restart_roundtrip",FoundationJson.StringifyPlain(first.Snapshot.State)==FoundationJson.StringifyPlain(loaded.Snapshot.State)&&first.RevisionId==loaded.RevisionId);
            Check("persistence_unknown_fields_lossless",loaded.Snapshot.CopyOriginals().All(p=>PersistencePaths.Hash(p.Value)==hashes[p.Key])&&PersistencePaths.Json(loaded.Snapshot.CopyOriginals()["savegame.json"]).Require("future").Require("kind").AsString()=="crop");
            Check("persistence_cosmetic_corruption_archived",loaded.Snapshot.Warnings.Count>0&&loaded.Snapshot.CopyOriginals()["controls.cfg"].SequenceEqual(before.Get("controls.cfg")));
            Check("persistence_settings_revision_saved",coordinator.SetPreferences(new LegacyPreferences("en",true,.2,.6))&&coordinator.Current.RevisionId!=first.RevisionId);
            var second=coordinator.Current;
            Check("persistence_original_state_not_replaced_by_preview",FoundationJson.StringifyPlain(second.Snapshot.State)==FoundationJson.StringifyPlain(first.Snapshot.State));
            Check("persistence_repeated_import_idempotent",coordinator.ImportSource(source)&&coordinator.Current.RevisionId==second.RevisionId&&coordinator.Preferences.Locale=="en");
            int failures=0;
            foreach(PersistenceWriteStage stage in Enum.GetValues(typeof(PersistenceWriteStage)))
            {
                bool injected=false;try{store.SavePreferences(second,second.Snapshot.Preferences,at=>{if(at==stage)throw new IOException("Injected interrupted write");});}catch(IOException){injected=true;}
                if(injected&&store.Load(first.ProfileId).RevisionId==second.RevisionId)failures++;
            }
            Check("persistence_atomic_failure_preserves_previous",failures==4);
            bool conflict=false;try{store.SavePreferences(first,first.Snapshot.Preferences);}catch(IOException){conflict=true;}
            Check("persistence_stale_writer_rejected",conflict&&store.Load(first.ProfileId).RevisionId==second.RevisionId);
            Check("persistence_restore_previous_revision",coordinator.RecoverPrevious()&&coordinator.Current.RevisionId==first.RevisionId&&coordinator.Preferences.Locale=="nl");
            string pointer=Path.Combine(target,first.ProfileId,"current.json");File.WriteAllText(pointer,"{truncated");
            bool corrupted=false;try{store.Load(first.ProfileId);}catch(FormatException){corrupted=true;}
            Check("persistence_corrupt_pointer_not_silently_reset",corrupted);
            var recovered=store.Recover(first.ProfileId,second.RevisionId);
            Check("persistence_explicit_recovery_after_corruption",store.Load(first.ProfileId).RevisionId==recovered.RevisionId);
            store.SavePreferences(recovered,PersistenceStore.Obj(("future",FoundationValue.StringValue("unusable preference format"))));
            store.Recover(first.ProfileId,second.RevisionId);
            string protectedPointer=PersistencePaths.Hash(File.ReadAllBytes(pointer));
            Check("persistence_semantically_invalid_recovery_preserves_pointer",!coordinator.RecoverProfile(first.ProfileId)&&PersistencePaths.Hash(File.ReadAllBytes(pointer))==protectedPointer);
            bool disjoint=false;try{new PersistenceStore(Path.Combine(source,"profiles")).Import(before,coordinator.Convert);}catch(IOException){disjoint=true;}
            Check("persistence_source_target_separated",disjoint&&!Directory.Exists(Path.Combine(source,"profiles")));
            bool traversal=false;try{store.Load("../godot-fixture");}catch(IOException){traversal=true;}
            Check("persistence_profile_traversal_rejected",traversal);
            // An invalid, unindexed ZIP entry cannot be used as a recoverable profile.
            string package=Path.Combine(target,first.ProfileId,"revisions",second.RevisionId+".bmq");byte[] originalPackage=File.ReadAllBytes(package);
            using(var stream=new FileStream(package,FileMode.Open,FileAccess.ReadWrite))using(var zip=new ZipArchive(stream,ZipArchiveMode.Update))using(var entry=zip.CreateEntry("../escape.txt").Open())entry.WriteByte(1);
            bool forged=false;try{store.Recover(first.ProfileId,second.RevisionId);}catch(IOException){forged=true;}
            File.WriteAllBytes(package,originalPackage);
            Check("persistence_archive_traversal_rejected",forged&&!File.Exists(Path.Combine(target,first.ProfileId,"escape.txt")));
            // Content damage is caught by the current pointer's whole-package hash and internal hashes.
            using(var stream=new FileStream(package,FileMode.Open,FileAccess.ReadWrite))using(var zip=new ZipArchive(stream,ZipArchiveMode.Update))
            {zip.GetEntry("state.json").Delete();using(var entry=zip.CreateEntry("state.json").Open()){byte[] bytes=PersistencePaths.Utf8.GetBytes("{}");entry.Write(bytes,0,bytes.Length);}}
            bool tamper=false;try{store.Load(first.ProfileId);}catch(Exception e)when(e is IOException||e is FormatException){tamper=true;}
            File.WriteAllBytes(package,originalPackage);Check("persistence_package_content_damage_rejected",tamper);
            foreach(string name in before.FileNames)File.SetAttributes(Path.Combine(source,name),FileAttributes.Normal);
            bool mutation=false;var changed=LegacySourceSet.Read(source);File.AppendAllText(Path.Combine(source,"settings.cfg"),"\n; fixture edit\n");
            try{changed.VerifyUnchanged();}catch(IOException){mutation=true;}File.WriteAllBytes(Path.Combine(source,"settings.cfg"),before.Get("settings.cfg"));
            Check("persistence_concurrent_source_change_rejected",mutation);
            before.VerifyUnchanged();Check("persistence_source_read_only",hashes.All(p=>PersistencePaths.Hash(File.ReadAllBytes(Path.Combine(source,p.Key)))==p.Value));
            Check("persistence_plain_kind_is_data",FoundationJson.ParsePlain(FoundationJson.StringifyPlain(FoundationJson.ParsePlain("{\"kind\":\"soil\",\"value\":{\"kind\":\"array\"}}"))).Require("kind").AsString()=="soil");
            int malformed=0;foreach(string invalid in new[]{"{\"a\":1,\"a\":2}","{\"a\":NaN}","{\"a\":1e999}","{\"a\":", "{\"a\":\"\\ud800\"}"})try{FoundationJson.ParsePlain(invalid);}catch(FormatException){malformed++;}
            Check("persistence_malformed_json_rejected",malformed==5);
            Check("persistence_revisions_and_pointer_backups_retained",store.Revisions(first.ProfileId).Count>=2&&Directory.GetFiles(Path.Combine(target,first.ProfileId,"pointer-backups")).Length>=2);
            Check("persistence_store_checks_ran",true);Check("persistence_no_real_saves_accessed",!PersistencePaths.Within(PersistencePaths.LegacyDefault,source)&&PersistencePaths.Within(output,area));
            // Leave a clean, synthetic profile on the public screenshot; no personal directory read.
            coordinator.OpenProfile(first.ProfileId);coordinator.SourceDirectory="Synthetische testopslag (geen persoonlijke bestanden)";Fixture=coordinator;
            return new Result{identity=identity,checks=checks.ToArray(),success=checks.All(c=>c.passed)};
        }
    }
}
