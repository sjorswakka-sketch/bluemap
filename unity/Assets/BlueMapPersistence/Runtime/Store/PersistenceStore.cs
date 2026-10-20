using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    public static class PersistencePaths
    {
        public static string LegacyDefault => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Godot","app_userdata","Bluemap Quest");
        public static string UnityDefault => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"BlueMapQuestUnity","Profiles");
        public static string Checked(string path)
        {
            if(string.IsNullOrWhiteSpace(path)||!Path.IsPathFullyQualified(path))throw new IOException("Kies een volledige maplocatie.");
            string full=Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
            if(full.Length<4)throw new IOException("Een systeemschijf kan geen opslagmap zijn.");
            string at=full;
            while(!string.IsNullOrEmpty(at))
            {
                FileAttributes? attributes=null;
                try{attributes=File.GetAttributes(at);}catch(FileNotFoundException){}catch(DirectoryNotFoundException){}
                if(attributes.HasValue&&(attributes.Value&FileAttributes.ReparsePoint)!=0)
                    throw new IOException("Een gekoppelde map of bestand kan niet als opslag worden gebruikt.");
                string next=Path.GetDirectoryName(at);if(next==at)break;at=next;
            }
            return full;
        }
        public static bool Within(string root,string path)
        {
            var comparison=Path.DirectorySeparatorChar=='\\'?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal;
            return string.Equals(root,path,comparison)||path.StartsWith(root+Path.DirectorySeparatorChar,comparison);
        }
        public static void Disjoint(string source,string target)
        {if(Within(source,target)||Within(target,source))throw new IOException("Godot-opslag en Unity-opslag moeten afzonderlijke mappen zijn.");}
        public static byte[] ReadBounded(string path,int maximum)
        {
            Checked(path);var info=new FileInfo(path);if(!info.Exists||info.Length>maximum)throw new IOException("Opslagbestand ontbreekt of is te groot.");
            using(var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite))return ReadBounded(stream,maximum);
        }
        public static byte[] ReadBounded(Stream stream,int maximum)
        {
            using(var output=new MemoryStream())
            {
                var chunk=new byte[16384];int count;
                while((count=stream.Read(chunk,0,chunk.Length))>0){if(output.Length+count>maximum)throw new IOException("Opslag overschrijdt de toegestane bestandsgrootte.");output.Write(chunk,0,count);}
                return output.ToArray();
            }
        }
        public static string Hash(byte[] bytes)
        {using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
        public static readonly UTF8Encoding Utf8=new UTF8Encoding(false,true);
        public static FoundationValue Json(byte[] bytes) => FoundationJson.ParsePlain(Utf8.GetString(bytes).TrimStart('\ufeff'));
    }
    // A bounded read-only snapshot of the five original files, with no directory-wide collection.
    public sealed class LegacySourceSet
    {
        public static readonly string[] Names={"savegame.json","settings.cfg","controls.cfg","meta.cfg","ng_plus.cfg"};
        readonly Dictionary<string,byte[]> files;
        public string DirectoryPath {get;}
        public string Fingerprint {get;}
        public IReadOnlyList<string> FileNames=>files.Keys.ToList().AsReadOnly();
        public byte[] Get(string name)=>files.TryGetValue(name,out var value)?(byte[])value.Clone():null;
        public Dictionary<string,byte[]> CopyFiles()=>files.ToDictionary(p=>p.Key,p=>(byte[])p.Value.Clone(),StringComparer.Ordinal);
        public LegacySourceSet(IDictionary<string,byte[]> source,string directoryPath=null)
        {
            files=new Dictionary<string,byte[]>(StringComparer.Ordinal);DirectoryPath=directoryPath;
            foreach(var pair in source)
            {
                if(!Names.Contains(pair.Key)||pair.Value==null||pair.Value.Length>Limit(pair.Key))throw new FormatException("Onbekend of te groot Godot-opslagbestand.");
                files.Add(pair.Key,(byte[])pair.Value.Clone());
            }
            if(files.Count==0)throw new IOException("Geen Godot-opslag of voorkeuren gevonden in deze map.");
            string identity=string.Join("\n",Names.Where(files.ContainsKey).Select(name=>name+":"+files[name].Length+":"+PersistencePaths.Hash(files[name])));
            Fingerprint=PersistencePaths.Hash(PersistencePaths.Utf8.GetBytes(identity));
        }
        public static int Limit(string name)=>name=="savegame.json"?8*1024*1024:1024*1024;
        public static LegacySourceSet Read(string sourceDirectory)
        {
            sourceDirectory=PersistencePaths.Checked(sourceDirectory);if(!Directory.Exists(sourceDirectory))throw new IOException("Deze Godot-opslagmap bestaat niet.");
            var files=new Dictionary<string,byte[]>(StringComparer.Ordinal);
            foreach(string name in Names){string path=Path.Combine(sourceDirectory,name);if(File.Exists(path))files.Add(name,PersistencePaths.ReadBounded(path,Limit(name)));}
            var result=new LegacySourceSet(files,sourceDirectory);result.VerifyUnchanged();return result;
        }
        public void VerifyUnchanged()
        {
            if(DirectoryPath==null)return;
            PersistencePaths.Checked(DirectoryPath);
            foreach(string name in Names)
            {
                string path=Path.Combine(DirectoryPath,name);bool exists=File.Exists(path);
                if(exists!=files.ContainsKey(name)||exists&&PersistencePaths.Hash(PersistencePaths.ReadBounded(path,Limit(name)))!=PersistencePaths.Hash(files[name]))
                    throw new IOException("De Godot-opslag is intussen gewijzigd. Lees de map opnieuw in.");
            }
        }
    }
    public sealed class PersistenceSnapshot
    {
        readonly Dictionary<string,byte[]> originals;
        public FoundationValue State {get;}
        public FoundationValue Preferences {get;}
        public string SourceFingerprint {get;}
        public IReadOnlyList<string> Warnings {get;}
        public Dictionary<string,byte[]> CopyOriginals()=>originals.ToDictionary(p=>p.Key,p=>(byte[])p.Value.Clone(),StringComparer.Ordinal);
        public PersistenceSnapshot(FoundationValue state,FoundationValue preferences,IDictionary<string,byte[]> originals,IEnumerable<string> warnings=null)
        {
            State=state??throw new ArgumentNullException(nameof(state));Preferences=preferences??throw new ArgumentNullException(nameof(preferences));
            var source=new LegacySourceSet(originals);this.originals=source.CopyFiles();SourceFingerprint=source.Fingerprint;
            Warnings=(warnings??Array.Empty<string>()).ToList().AsReadOnly();ValidateState(state);
            if(preferences.Kind!="object"&&preferences.Kind!="dictionary")throw new FormatException("Voorkeuren moeten een object zijn.");
        }
        public PersistenceSnapshot WithPreferences(FoundationValue preferences)=>new PersistenceSnapshot(State,preferences,originals,Warnings);
        public static void ValidateState(FoundationValue state)
        {
            if(state.Kind!="object"&&state.Kind!="dictionary")throw new FormatException("Het Unity-avontuur moet een object zijn.");
            foreach(string key in FoundationGameState.SaveKeys)state.Require(key);
            string map=state.Require("map").AsString();if(map.Length==0||map.Length>200)throw new FormatException("Onbruikbare gebiedsnaam.");
            var position=state.Require("pos");if(position.Kind!="array"||position.Items.Count!=2)throw new FormatException("Onbruikbare spelerspositie.");
            foreach(var coordinate in position.Items)if(Math.Abs(coordinate.AsDouble())>float.MaxValue)throw new FormatException("Spelerspositie kan niet veilig worden hersteld.");
            state.Require("hp").AsInt64();state.Require("coins").AsInt64();state.Require("play_time").AsDouble();
            FoundationJson.StringifyPlain(state);FoundationJson.StringifyPlain(state.Require("inventory"));
        }
    }
    public sealed class PersistenceRevision
    {
        public string ProfileId {get;internal set;}
        public string RevisionId {get;internal set;}
        public string PackageSha256 {get;internal set;}
        public string CreatedUtc {get;internal set;}
        public PersistenceSnapshot Snapshot {get;internal set;}
    }
    public enum PersistenceWriteStage { PackageStarted,PackageFlushed,PackageVerified,BeforePointerCommit }

    // Each revision is immutable. Only the tiny current pointer is replaced atomically;
    // its old bytes are retained as a backup. Source files are never opened for writing.
    public sealed class PersistenceStore
    {
        public string Root {get;}
        const int PackageLimit=32*1024*1024,TotalLimit=32*1024*1024;
        static readonly Regex ProfilePattern=new Regex(@"\A[a-z0-9][a-z0-9_-]{0,95}\z");
        static readonly Regex RevisionPattern=new Regex(@"\A[0-9a-f]{32}\z");
        static readonly Regex HashPattern=new Regex(@"\A[0-9a-f]{64}\z");
        public PersistenceStore(string root){Root=PersistencePaths.Checked(root);}
        string Folder(string profile)
        {
            if(profile==null||!ProfilePattern.IsMatch(profile))throw new IOException("Ongeldige profielnaam.");
            string path=PersistencePaths.Checked(Path.Combine(Root,profile));if(!PersistencePaths.Within(Root,path))throw new IOException("Ongeldige opslaglocatie.");return path;
        }
        string RevisionPath(string profile,string revision)
        {if(revision==null||!RevisionPattern.IsMatch(revision))throw new IOException("Ongeldige bewaarkopie.");return PersistencePaths.Checked(Path.Combine(Folder(profile),"revisions",revision+".bmq"));}
        public IReadOnlyList<string> ProfileIds()
        {
            PersistencePaths.Checked(Root);if(!Directory.Exists(Root))return Array.Empty<string>();
            return Directory.GetDirectories(Root).Select(Path.GetFileName).Where(name=>ProfilePattern.IsMatch(name)).OrderBy(name=>name,StringComparer.Ordinal).ToArray();
        }
        public PersistenceRevision Import(LegacySourceSet source,Func<LegacySourceSet,PersistenceSnapshot> convert,Action<PersistenceWriteStage> fault=null)
        {
            if(source==null||convert==null)throw new ArgumentNullException();
            if(source.DirectoryPath!=null)PersistencePaths.Disjoint(source.DirectoryPath,Root);
            string profile="legacy-"+source.Fingerprint.Substring(0,32);string pointer=Path.Combine(Folder(profile),"current.json");
            source.VerifyUnchanged();
            if(File.Exists(pointer))
            {
                var current=Load(profile);if(current.Snapshot.SourceFingerprint!=source.Fingerprint)throw new IOException("Profielidentiteit komt niet overeen.");
                return current; // Repeating the same import must not reset Unity preferences.
            }
            var snapshot=convert(source);if(snapshot.SourceFingerprint!=source.Fingerprint)throw new IOException("De import heeft bronbestanden veranderd.");
            source.VerifyUnchanged();return Commit(profile,snapshot,null,stage=>{fault?.Invoke(stage);if(stage==PersistenceWriteStage.BeforePointerCommit)source.VerifyUnchanged();});
        }
        public PersistenceRevision Load(string profile)
        {
            string pointer=PersistencePaths.Checked(Path.Combine(Folder(profile),"current.json"));
            var root=PersistencePaths.Json(PersistencePaths.ReadBounded(pointer,65536));
            if(root.Require("schemaVersion").AsInt64()!=1||root.Require("profile").AsString()!=profile)throw new IOException("Onbekend Unity-opslagformaat.");
            string revision=root.Require("revision").AsString(),hash=root.Require("sha256").AsString();
            if(!HashPattern.IsMatch(hash))throw new IOException("Beschadigde opslagverwijzing.");
            return ReadRevision(profile,revision,hash);
        }
        public IReadOnlyList<PersistenceRevision> Revisions(string profile)
        {
            string directory=PersistencePaths.Checked(Path.Combine(Folder(profile),"revisions"));var found=new List<PersistenceRevision>();if(!Directory.Exists(directory))return found;
            var names=Directory.GetFiles(directory,"*.bmq");if(names.Length>4096)throw new IOException("Te veel bewaarkopieën; kies een profielmap.");
            foreach(string path in names)
            {
                string name=Path.GetFileNameWithoutExtension(path);if(!RevisionPattern.IsMatch(name))continue;
                try{found.Add(ReadRevision(profile,name,null));}catch(IOException){}catch(FormatException){}
            }
            return found.OrderByDescending(value=>value.CreatedUtc,StringComparer.Ordinal).ThenByDescending(value=>value.RevisionId,StringComparer.Ordinal).ToArray();
        }
        public PersistenceRevision Recover(string profile,string revision,Action<PersistenceRevision> validate=null)
        {
            string folder=Folder(profile);Directory.CreateDirectory(folder);
            using(var lease=Lease(folder)){var prepared=ReadRevision(profile,revision,null);validate?.Invoke(prepared);CommitPointer(folder,profile,prepared.RevisionId,prepared.PackageSha256);return prepared;}
        }
        public PersistenceRevision SavePreferences(PersistenceRevision current,FoundationValue preferences,Action<PersistenceWriteStage> fault=null)
        {if(current==null)throw new ArgumentNullException(nameof(current));return Commit(current.ProfileId,current.Snapshot.WithPreferences(preferences),current.RevisionId,fault);}
        public PersistenceRevision Commit(string profile,PersistenceSnapshot snapshot,string expectedRevision,Action<PersistenceWriteStage> fault=null)
        {
            string folder=Folder(profile);Directory.CreateDirectory(folder);PersistencePaths.Checked(folder);
            using(var lease=Lease(folder))
            {
                string pointer=PersistencePaths.Checked(Path.Combine(folder,"current.json"));
                if(File.Exists(pointer))
                {var current=Load(profile);if(current.RevisionId!=expectedRevision)throw new IOException("Dit profiel is intussen gewijzigd. Open het opnieuw.");}
                else if(expectedRevision!=null)throw new IOException("De vorige opslagverwijzing ontbreekt; herstel eerst een bewaarkopie.");
                string revision=Guid.NewGuid().ToString("N"),created=DateTime.UtcNow.ToString("O",System.Globalization.CultureInfo.InvariantCulture);
                string revisions=PersistencePaths.Checked(Path.Combine(folder,"revisions"));Directory.CreateDirectory(revisions);
                string staging=PersistencePaths.Checked(Path.Combine(revisions,".staging-"+revision+".tmp"));
                WritePackage(staging,profile,revision,created,snapshot,fault);
                fault?.Invoke(PersistenceWriteStage.PackageFlushed);
                var verified=ReadPackage(staging,profile,revision);fault?.Invoke(PersistenceWriteStage.PackageVerified);
                string destination=RevisionPath(profile,revision);File.Move(staging,destination);
                fault?.Invoke(PersistenceWriteStage.BeforePointerCommit);
                CommitPointer(folder,profile,revision,verified.PackageSha256);
                return verified;
            }
        }
        static FileStream Lease(string folder)
        {string path=PersistencePaths.Checked(Path.Combine(folder,".write.lock"));return new FileStream(path,FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);}
        static void CommitPointer(string folder,string profile,string revision,string hash)
        {
            string pointer=PersistencePaths.Checked(Path.Combine(folder,"current.json"));
            string pending=PersistencePaths.Checked(Path.Combine(folder,".pointer-"+Guid.NewGuid().ToString("N")+".tmp"));
            var value=Obj(("schemaVersion",FoundationValue.Integer(1)),("profile",FoundationValue.StringValue(profile)),("revision",FoundationValue.StringValue(revision)),("sha256",FoundationValue.StringValue(hash)));
            byte[] bytes=PersistencePaths.Utf8.GetBytes(FoundationJson.StringifyPlain(value));
            using(var stream=new FileStream(pending,FileMode.CreateNew,FileAccess.Write,FileShare.None)){stream.Write(bytes,0,bytes.Length);stream.Flush(true);}
            PersistencePaths.Json(PersistencePaths.ReadBounded(pending,65536));
            if(File.Exists(pointer))
            {
                string backups=PersistencePaths.Checked(Path.Combine(folder,"pointer-backups"));Directory.CreateDirectory(backups);
                string backup=PersistencePaths.Checked(Path.Combine(backups,Guid.NewGuid().ToString("N")+".json"));
                File.Replace(pending,pointer,backup);
            }
            else File.Move(pending,pointer);
        }
        PersistenceRevision ReadRevision(string profile,string revision,string expectedHash)
        {var result=ReadPackage(RevisionPath(profile,revision),profile,revision);if(expectedHash!=null&&result.PackageSha256!=expectedHash)throw new IOException("De bewaarkopie is beschadigd; gebruik een eerdere kopie.");return result;}
        static bool Allowed(string name)=>name=="profile.json"||name=="state.json"||name=="preferences.json"||LegacySourceSet.Names.Any(file=>name=="legacy/"+file);
        static int Limit(string name)=>name=="profile.json"?65536:name=="state.json"?16*1024*1024:name=="preferences.json"?4*1024*1024:LegacySourceSet.Limit(name.Substring(7));
        static void WritePackage(string path,string profile,string revision,string created,PersistenceSnapshot snapshot,Action<PersistenceWriteStage> fault)
        {
            var data=new Dictionary<string,byte[]>(StringComparer.Ordinal){{"state.json",PersistencePaths.Utf8.GetBytes(FoundationJson.StringifyPlain(snapshot.State))},{"preferences.json",PersistencePaths.Utf8.GetBytes(FoundationJson.StringifyPlain(snapshot.Preferences))}};
            foreach(var pair in snapshot.CopyOriginals())data.Add("legacy/"+pair.Key,pair.Value);
            var files=FoundationValue.Array(data.OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>Obj(("name",FoundationValue.StringValue(p.Key)),("bytes",FoundationValue.Integer(p.Value.LongLength)),("sha256",FoundationValue.StringValue(PersistencePaths.Hash(p.Value))))));
            var metadata=Obj(("schemaVersion",FoundationValue.Integer(1)),("format",FoundationValue.StringValue("bluemap.unity.profile")),("profile",FoundationValue.StringValue(profile)),("revision",FoundationValue.StringValue(revision)),("createdUtc",FoundationValue.StringValue(created)),("sourceFingerprint",FoundationValue.StringValue(snapshot.SourceFingerprint)),("files",files),("warnings",FoundationValue.Array(snapshot.Warnings.Select(FoundationValue.StringValue))));
            data.Add("profile.json",PersistencePaths.Utf8.GetBytes(FoundationJson.StringifyPlain(metadata)));
            long total=0;foreach(var pair in data){if(pair.Value.Length>Limit(pair.Key))throw new IOException("Het profiel is te groot.");total+=pair.Value.Length;}if(total>TotalLimit)throw new IOException("Het profiel is te groot.");
            using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.ReadWrite,FileShare.None))
            {
                using(var zip=new ZipArchive(stream,ZipArchiveMode.Create,true))
                {
                    bool first=true;
                    foreach(var pair in data.OrderBy(p=>p.Key,StringComparer.Ordinal))
                    {
                        var entry=zip.CreateEntry(pair.Key,CompressionLevel.Optimal);using(var target=entry.Open())target.Write(pair.Value,0,pair.Value.Length);
                        if(first){first=false;fault?.Invoke(PersistenceWriteStage.PackageStarted);}
                    }
                }
                stream.Flush(true);
            }
        }
        static PersistenceRevision ReadPackage(string path,string profile,string revision)
        {
            byte[] packed=PersistencePaths.ReadBounded(path,PackageLimit);var files=new Dictionary<string,byte[]>(StringComparer.Ordinal);
            using(var memory=new MemoryStream(packed,false))using(var zip=new ZipArchive(memory,ZipArchiveMode.Read,false))
            {
                if(zip.Entries.Count<4||zip.Entries.Count>8)throw new IOException("Onvolledig of onbekend Unity-profiel.");
                long total=0;
                foreach(var entry in zip.Entries)
                {
                    string name=entry.FullName;if(!Allowed(name)||files.ContainsKey(name)||entry.Length<0||entry.Length>Limit(name))throw new IOException("Ongeldige profielinhoud.");
                    total+=entry.Length;if(total>TotalLimit)throw new IOException("Het profiel is te groot.");
                    using(var stream=entry.Open()){byte[] bytes=PersistencePaths.ReadBounded(stream,Limit(name));if(bytes.LongLength!=entry.Length)throw new IOException("Afgebroken profielinhoud.");files.Add(name,bytes);}
                }
            }
            foreach(string required in new[]{"profile.json","state.json","preferences.json"})if(!files.ContainsKey(required))throw new IOException("Onvolledige bewaarkopie.");
            var metadata=PersistencePaths.Json(files["profile.json"]);
            if(metadata.Require("schemaVersion").AsInt64()!=1||metadata.Require("format").AsString()!="bluemap.unity.profile"||metadata.Require("profile").AsString()!=profile||metadata.Require("revision").AsString()!=revision)throw new IOException("Onbekende bewaarkopie of verkeerde profielidentiteit.");
            var indexed=new HashSet<string>(StringComparer.Ordinal);
            foreach(var row in metadata.Require("files").Items)
            {
                string name=row.Require("name").AsString();if(name=="profile.json"||!indexed.Add(name)||!files.TryGetValue(name,out var bytes)||row.Require("bytes").AsInt64()!=bytes.LongLength||row.Require("sha256").AsString()!=PersistencePaths.Hash(bytes))throw new IOException("Beschadigde profielinhoud.");
            }
            if(indexed.Count!=files.Count-1)throw new IOException("Niet alle profielinhoud is gecontroleerd.");
            var originals=new Dictionary<string,byte[]>(StringComparer.Ordinal);foreach(string name in LegacySourceSet.Names)if(files.TryGetValue("legacy/"+name,out var bytes))originals.Add(name,bytes);
            var snapshot=new PersistenceSnapshot(PersistencePaths.Json(files["state.json"]),PersistencePaths.Json(files["preferences.json"]),originals,metadata.Require("warnings").Items.Select(v=>v.AsString()));
            if(snapshot.SourceFingerprint!=metadata.Require("sourceFingerprint").AsString())throw new IOException("De oorspronkelijke opslagbytes zijn gewijzigd.");
            return new PersistenceRevision{ProfileId=profile,RevisionId=revision,PackageSha256=PersistencePaths.Hash(packed),CreatedUtc=metadata.Require("createdUtc").AsString(),Snapshot=snapshot};
        }
        public static FoundationValue Obj(params (string name,FoundationValue value)[] entries)=>FoundationValue.Object(entries.ToDictionary(p=>p.name,p=>p.value,StringComparer.Ordinal));
    }
}
