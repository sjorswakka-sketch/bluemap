using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;

namespace BlueMapMigration.Persistence
{
    // Technical previews never save their walking state. Real route sessions use an
    // explicit separate profile, retaining the imported profile and every old revision.
    public sealed class PersistenceCoordinator : IDisposable
    {
        readonly FoundationWorldRepository repository;
        readonly PlayerInputSource input;
        readonly PersistenceStore store;
        bool applying;
        public PersistenceRevision Current {get;private set;}
        public LegacyPreferences Preferences {get;private set;} = new LegacyPreferences();
        public string SourceDirectory {get;set;} = PersistencePaths.LegacyDefault;
        public string Status {get;private set;} = "Kies een Godot-opslagmap en importeer een veilige kopie, of open een Unity-profiel.";
        public IReadOnlyList<string> Profiles {get;private set;} = Array.Empty<string>();
        public bool HasProfile => Current != null;
        public bool IsRouteProfile => Current!=null&&Current.Snapshot.Preferences.TryGet("routeBranch",out var branch)&&branch.TryGet("schemaVersion",out var version)&&version.Kind=="int"&&version.AsInt64()==1;
        public event Action PreferencesChanged;
        public PersistenceCoordinator(FoundationWorldRepository repository,PlayerInputSource input,string root)
        {
            this.repository=repository;this.input=input;store=new PersistenceStore(root);
            input.BindingsChanged+=BindingsChanged;RefreshProfiles();
        }
        bool Try(Action action)
        {try{action();return true;}catch(Exception error)when(error is System.IO.IOException||error is System.IO.InvalidDataException||error is FormatException||error is UnauthorizedAccessException||error is OverflowException||error is ArgumentException){Status="Niet gewijzigd: "+error.Message;return false;}}
        public bool RefreshProfiles()=>Try(()=>{Profiles=store.ProfileIds();});
        public PersistenceSnapshot Convert(LegacySourceSet source)
        {
            var importer=new LegacySaveImporter(repository);
            var settings=LegacySettingsBundle.Decode(source.Get("settings.cfg"),source.Get("controls.cfg"),source.Get("meta.cfg"),source.Get("ng_plus.cfg"),input,importer,Environment.GetEnvironmentVariable("BLUEMAP_LANG"),System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName);
            var save=source.Get("savegame.json");
            var imported=importer.Import(save??PersistencePaths.Utf8.GetBytes("{}"),settings.Achievements);
            var preferences=PersistenceStore.Obj(("audioLanguage",settings.Preferences.ToValue()),("bindings",settings.Bindings),("achievements",settings.Achievements),("ngMeta",settings.NgMeta));
            // Source normalization owns the 34 known fields. Future top-level data remains
            // inert ordinary JSON alongside them, as well as in the exact source bytes.
            var fields=imported.State.Snapshot().Entries.ToDictionary(pair=>pair.Key.AsString(),pair=>pair.Value,StringComparer.Ordinal);
            if(save!=null)
            {
                var raw=PersistencePaths.Json(save);
                if(raw.Kind=="object"||raw.Kind=="dictionary")foreach(var pair in raw.Entries)if(!fields.ContainsKey(pair.Key.AsString()))fields.Add(pair.Key.AsString(),pair.Value);
            }
            return new PersistenceSnapshot(FoundationValue.Object(fields),preferences,source.CopyFiles(),settings.Diagnostics.Concat(imported.Warnings));
        }
        public bool ImportSource(string directory)=>Try(()=>
        {
            SourceDirectory=directory;var source=LegacySourceSet.Read(directory);
            // Validate the entire projected profile before making it the active one.
            var candidate=store.Import(source,Convert);Apply(candidate);Profiles=store.ProfileIds();
            Status="Veilige kopie geopend. Originele Godot-bestanden zijn ongewijzigd; "+candidate.Snapshot.State.Require("map").AsString()+", "+candidate.Snapshot.State.Require("coins").AsInt64()+" munten. "+candidate.Snapshot.Warnings.Count+" aandachtspunten.";
        });
        public bool OpenProfile(string profile)=>Try(()=>{Apply(store.Load(profile));Status="Unity-profiel geopend. Voortgang en originele bestanden zijn bewaard.";});
        public bool CreateRouteCopy(FoundationValue state,bool copyAdventure)=>Try(()=>
        {
            PersistenceSnapshot.ValidateState(state);
            if(copyAdventure&&Current==null)throw new System.IO.IOException("Open eerst een profiel om een speelkopie te maken.");
            var parent=Current;
            FoundationValue preferences;
            if(parent!=null)preferences=parent.Snapshot.Preferences;
            else
            {
                var defaults=LegacySettingsBundle.Decode(null,null,null,null,input,new LegacySaveImporter(repository),Preferences.Locale,"nl");
                preferences=PersistenceStore.Obj(("audioLanguage",Preferences.ToValue()),("bindings",LegacySettingsBundle.BindingValue(input)),("achievements",defaults.Achievements),("ngMeta",defaults.NgMeta));
            }
            var fields=preferences.Entries.ToDictionary(pair=>pair.Key.AsString(),pair=>pair.Value,StringComparer.Ordinal);
            fields["routeBranch"]=PersistenceStore.Obj(("schemaVersion",FoundationValue.Integer(1)),("mode",FoundationValue.StringValue(copyAdventure?"copy":"new")),("parentProfile",FoundationValue.StringValue(parent?.ProfileId??"")),("parentRevision",FoundationValue.StringValue(parent?.RevisionId??"")),("sourceMap",parent?.Snapshot.State.Require("map")??state.Require("map")),("sourcePosition",parent?.Snapshot.State.Require("pos")??state.Require("pos")));
            var originals=copyAdventure?parent.Snapshot.CopyOriginals():new Dictionary<string,byte[]>(StringComparer.Ordinal);
            string origin=copyAdventure?parent.Snapshot.Origin:"unity";
            var snapshot=new PersistenceSnapshot(state,FoundationValue.Object(fields),originals,copyAdventure?parent.Snapshot.Warnings:null,origin);
            var candidate=store.Commit("route-"+Guid.NewGuid().ToString("N"),snapshot,null);
            Apply(candidate);Profiles=store.ProfileIds();Status=copyAdventure?"Aparte speelkopie gemaakt; het oorspronkelijke profiel blijft behouden.":"Nieuw avontuur gestart in een apart Unity-profiel.";
        });
        public bool SaveAdventure(FoundationValue state,Action<PersistenceWriteStage> fault=null)=>Try(()=>
        {
            if(!IsRouteProfile)throw new System.IO.IOException("Een avontuur kan alleen in een aparte speelkopie worden bewaard.");
            var snapshot=Current.Snapshot.WithState(state);
            Current=store.Commit(Current.ProfileId,snapshot,Current.RevisionId,fault);
            Status="Je avontuur is opgeslagen. De vorige bewaarkopie blijft beschikbaar.";
        });
        public bool ReloadAdventure()=>Try(()=>
        {if(!IsRouteProfile)throw new System.IO.IOException("Open eerst een speelprofiel.");Apply(store.Load(Current.ProfileId));Status="Opgeslagen avontuur geladen.";});
        public bool RecoverPrevious()=>Try(()=>
        {
            if(Current==null)throw new System.IO.IOException("Open eerst een profiel.");
            var previous=store.Revisions(Current.ProfileId).FirstOrDefault(value=>value.RevisionId!=Current.RevisionId&&StringComparer.Ordinal.Compare(value.CreatedUtc,Current.CreatedUtc)<0);
            if(previous==null)throw new System.IO.IOException("Er is nog geen eerdere bewaarkopie.");
            Apply(store.Recover(Current.ProfileId,previous.RevisionId,Validate));Status="Eerdere bewaarkopie hersteld; alle andere kopieën blijven bewaard.";
        });
        public bool RecoverProfile(string profile)=>Try(()=>
        {
            var revision=store.Revisions(profile).FirstOrDefault();if(revision==null)throw new System.IO.IOException("Geen geldige bewaarkopie gevonden.");
            Apply(store.Recover(profile,revision.RevisionId,Validate));Status="Geldige bewaarkopie geopend; beschadigde gegevens zijn behouden.";
        });
        void Apply(PersistenceRevision revision)
        {
            Validate(revision);
            var preferences=LegacyPreferences.FromValue(revision.Snapshot.Preferences.Require("audioLanguage"));
            applying=true;try{LegacySettingsBundle.ApplyBindingValue(input,revision.Snapshot.Preferences.Require("bindings"));Current=revision;Preferences=preferences;}finally{applying=false;}
            PreferencesChanged?.Invoke();
        }
        static void Validate(PersistenceRevision revision)
        {
            LegacyPreferences.FromValue(revision.Snapshot.Preferences.Require("audioLanguage"));
            using(var validation=new PlayerInputSource())LegacySettingsBundle.ApplyBindingValue(validation,revision.Snapshot.Preferences.Require("bindings"));
        }
        FoundationValue Updated(LegacyPreferences preference,bool bindingsChanged)
        {
            var fields=Current.Snapshot.Preferences.Entries.ToDictionary(pair=>pair.Key.AsString(),pair=>pair.Value,StringComparer.Ordinal);
            var audio=fields["audioLanguage"].Entries.ToDictionary(pair=>pair.Key.AsString(),pair=>pair.Value,StringComparer.Ordinal);
            foreach(var pair in preference.ToValue().Entries)audio[pair.Key.AsString()]=pair.Value;
            fields["audioLanguage"]=FoundationValue.Object(audio);if(bindingsChanged)fields["bindings"]=LegacySettingsBundle.BindingValue(input);return FoundationValue.Object(fields);
        }
        public bool SetPreferences(LegacyPreferences preferences)=>StorePreferences(preferences,false);
        bool StorePreferences(LegacyPreferences preferences,bool bindingsChanged)=>Try(()=>
        {
            if(Current!=null)Current=store.SavePreferences(Current,Updated(preferences,bindingsChanged));
            Preferences=preferences;PreferencesChanged?.Invoke();Status=Current==null?"Tijdelijk toegepast; importeer of open een profiel om instellingen te bewaren.":"Instellingen opgeslagen in een nieuwe bewaarkopie.";
        });
        void BindingsChanged()
        {
            if(applying)return;
            if(!StorePreferences(Preferences,true)&&Current!=null)
            {applying=true;try{LegacySettingsBundle.ApplyBindingValue(input,Current.Snapshot.Preferences.Require("bindings"));}finally{applying=false;}}
        }
        public void Dispose(){input.BindingsChanged-=BindingsChanged;}
    }
}
