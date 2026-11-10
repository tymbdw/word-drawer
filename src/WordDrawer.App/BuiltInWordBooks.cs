using System.Reflection;
using System.Text.Json;
using WordDrawer.Core;

namespace WordDrawer.App;

/// <summary>One bundled wordbook: where it comes from and which embedded resource holds it.</summary>
internal sealed record WordBookDefinition(string Key, string Name, string Source, string ResourceName);

/// <summary>
/// The wordbooks shipped inside the executable. Every set is a tag-select of ECDICT
/// (https://github.com/skywind3000/ECDICT, MIT): headword, part of speech and a trimmed gloss.
/// </summary>
internal static class BuiltInWordBooks
{
    private const string Attribution = "ECDICT (MIT) — tag: {0}; 词性/释义为公开数据整理";

    public static IReadOnlyList<WordBookDefinition> All { get; } =
    [
        new("cet4", "四级核心词汇", string.Format(Attribution, "cet4"),
            "WordDrawer.App.Assets.cet4-2027.json"),
        new("cet6", "六级核心词汇", string.Format(Attribution, "cet6"),
            "WordDrawer.App.Assets.cet6-2027.json"),
        new("ky", "2027 考研英语大纲词汇", string.Format(Attribution, "ky"),
            "WordDrawer.App.Assets.kaoyan-2027.json"),
    ];

    private static readonly Dictionary<string, IReadOnlyList<StudyWord>> Cache = new(StringComparer.Ordinal);

    public static IReadOnlyList<StudyWord> Load(WordBookDefinition book)
    {
        if (Cache.TryGetValue(book.Key, out var cached))
        {
            return cached;
        }

        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(book.ResourceName)
            ?? throw new InvalidOperationException($"缺少内置词书资源 {book.ResourceName}");

        var entries = JsonSerializer.Deserialize<List<Entry>>(stream, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? [];

        var words = entries
            .Select(entry => new StudyWord(
                0,
                entry.I,
                entry.W,
                string.IsNullOrWhiteSpace(entry.P) ? "·" : entry.P.Trim(),
                entry.M.Trim()))
            .ToArray();

        Cache[book.Key] = words;
        return words;
    }

    private sealed record Entry(int I, string W, string P, string M);
}
