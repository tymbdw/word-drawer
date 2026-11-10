namespace WordDrawer.Data;

public sealed record DashboardSnapshot(
    int UniqueWordsStudied,
    int TodayUniqueWordsStudied,
    int DueReviewCount,
    long EffectiveStudySeconds);

/// <summary>One day of study totals.</summary>
public sealed record DailyStat(DateOnly Date, int UniqueWordsStudied, long EffectiveSeconds);

/// <summary>One row of the wordbook list.</summary>
public sealed record WordBookSummary(int Id, string Name, string Source, bool IsActive, int WordCount, int LearnedCount);
