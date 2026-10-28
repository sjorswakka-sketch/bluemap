using System;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Story
{
    public sealed partial class StoryModel
    {
        // A live object may contribute source effects before a following dialogue branch is selected.
        // It only receives the transaction stage. Real actors and UI are synchronized after commit.
        public Func<StoryModel, FoundationValue, bool> ContextActionResolver { get; set; }

        public bool ApplySourceBatch(Action<StoryModel> mutate)
        {
            if (mutate == null) throw new ArgumentNullException(nameof(mutate));
            return Operation(() => { RunSourceTransaction(mutate); return true; });
        }

        void RequireSourceStage()
        {
            if (!staging) throw new InvalidOperationException("Source effects require an isolated story transaction stage.");
        }
        public void SourceGive(string id, long amount, bool quiet = false)
        { RequireSourceStage(); GiveDirect(id, amount, quiet); }
        public void SourceTake(string id, long amount)
        { RequireSourceStage(); TakeDirect(id, amount); }
        public void SourceFlag(string id, bool value = true)
        { RequireSourceStage(); SetFlagDirect(id, value); }
        public void SourceStart(string id)
        { RequireSourceStage(); StartDirect(id); }
        public void SourceFinish(string id)
        { RequireSourceStage(); FinishDirect(id); }
        public void SourceEmit(string kind, FoundationValue payload = null)
        { RequireSourceStage(); Emit(kind, payload); }
        public void SourceSetField(string name, FoundationValue value)
        { RequireSourceStage(); State.Set(name, value); }
    }
}
