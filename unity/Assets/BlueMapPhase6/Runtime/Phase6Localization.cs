using System;
using System.Collections.Generic;

namespace BlueMapMigration.Phase6
{
    public sealed class Phase6Localization
    {
        private readonly Dictionary<string, LocalizationDefinition> entries = new Dictionary<string, LocalizationDefinition>(StringComparer.Ordinal);
        public int Count => entries.Count;
        public Phase6Localization(Phase6Catalog catalog)
        {
            foreach (LocalizationDefinition entry in catalog.localization)
            {
                string key = Key(entry.context, entry.source);
                if (entries.ContainsKey(key)) throw new InvalidOperationException("Duplicate original translation context/source pair.");
                entries.Add(key, entry);
            }
        }
        private static string Key(string context, string source) => (context ?? "") + "\0" + (source ?? "");

        // Lookup happens before any caller-owned % or {token} formatting.
        public string Translate(string source, string context = "", string plural = "", long count = 1, string locale = "nl")
        {
            source = source ?? "";
            bool many = count != 1;
            if (!entries.TryGetValue(Key(context, source), out LocalizationDefinition entry))
                return many && !string.IsNullOrEmpty(plural) ? plural : source;
            bool entryPlural = !string.IsNullOrEmpty(entry.plural);
            int index = entryPlural && many ? 1 : 0;
            string fallback = index == 1 ? entry.plural : entry.source;
            if (locale == "en" && !entry.fuzzy && entry.translated && entry.en != null && index < entry.en.Length && !string.IsNullOrEmpty(entry.en[index]))
                return entry.en[index];
            if (locale == "nl" && entry.nl != null && index < entry.nl.Length && !string.IsNullOrEmpty(entry.nl[index]))
                return entry.nl[index];
            return fallback;
        }
    }
}
