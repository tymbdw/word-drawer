using WordDrawer.Core;
using WordDrawer.Data;

namespace WordDrawer.Data.Tests;

public sealed class WordDrawerDatabaseTests : IAsyncLifetime
{
    private readonly string _databasePath = Path.Combine(
        Path.GetTempPath(),
        $"worddrawer-test-{Guid.NewGuid():N}.db");

    private WordDrawerDatabase Database => new(_databasePath);

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync()
    {
        foreach (var suffix in new[] { string.Empty, "-wal", "-shm" })
        {
            var path = _databasePath + suffix;
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }

        return Task.CompletedTask;
    }

    [Fact]
    public async Task SeededWordsAreReturnedInSequenceOrder()
    {
        var database = Database;
        await database.InitializeAsync();
        await database.SeedWordBookAsync(
            "测试词书",
            "test fixture",
            [
                new StudyWord(0, 2, "beta", "n.", "第二个"),
                new StudyWord(0, 1, "alpha", "n.", "第一个")
            ]);

        var words = await database.GetNextUnstudiedWordsAsync(10);

        Assert.Equal(["alpha", "beta"], words.Select(word => word.English));
    }

    [Fact]
    public async Task RepeatedReviewCountsUniqueWordOnlyOnce()
    {
        var database = Database;
        await database.InitializeAsync();
        await database.SeedWordBookAsync(
            "测试词书",
            "test fixture",
            [new StudyWord(0, 1, "alpha", "n.", "第一个")]);
        var word = Assert.Single(await database.GetNextUnstudiedWordsAsync(10));
        var now = new DateTimeOffset(2026, 10, 17, 9, 0, 0, TimeSpan.FromHours(8));

        await database.RecordFeedbackAsync(word.Id, WordFeedback.Known, now, new DateOnly(2026, 10, 19), 2, 5.2, 1, 1);
        await database.RecordFeedbackAsync(word.Id, WordFeedback.Known, now.AddMinutes(5), new DateOnly(2026, 10, 23), 5, 5.1, 2, 2);

        var dashboard = await database.GetDashboardAsync(new DateOnly(2026, 10, 17));
        Assert.Equal(1, dashboard.UniqueWordsStudied);
        Assert.Equal(1, dashboard.TodayUniqueWordsStudied);
        Assert.Equal(2, await database.GetReviewEventCountAsync());
    }

    [Fact]
    public async Task DueQueueReturnsOnlyDueWordsWithTheirMemoryState()
    {
        var database = Database;
        await database.InitializeAsync();
        await database.SeedWordBookAsync(
            "测试词书",
            "test fixture",
            [
                new StudyWord(0, 1, "alpha", "n.", "第一个"),
                new StudyWord(0, 2, "beta", "n.", "第二个")
            ]);
        var words = await database.GetNextUnstudiedWordsAsync(10);
        var now = new DateTimeOffset(2026, 10, 17, 9, 0, 0, TimeSpan.FromHours(8));

        // alpha is due today, beta is due next week
        await database.RecordFeedbackAsync(words[0].Id, WordFeedback.Unknown, now, new DateOnly(2026, 10, 17), 0.4, 7.2, 0, 1);
        await database.RecordFeedbackAsync(words[1].Id, WordFeedback.Known, now, new DateOnly(2026, 10, 24), 3.17, 5.28, 1, 1);

        var due = await database.GetDueReviewItemsAsync(new DateOnly(2026, 10, 17));

        var item = Assert.Single(due);
        Assert.Equal("alpha", item.English);
        Assert.Equal(7.2, item.Card.Difficulty, 3);
        Assert.Equal(1, item.Card.Repetitions);
        Assert.Equal(new DateOnly(2026, 10, 17), item.Card.LastReviewedDate);
    }

    [Fact]
    public async Task ReleasedDateIsPersistedAndOnlySetOnce()
    {
        var database = Database;
        await database.InitializeAsync();
        await database.SeedWordBookAsync(
            "测试词书",
            "test fixture",
            [new StudyWord(0, 1, "alpha", "n.", "第一个")]);
        var word = Assert.Single(await database.GetNextUnstudiedWordsAsync(10));
        var now = new DateTimeOffset(2026, 10, 17, 9, 0, 0, TimeSpan.FromHours(8));
        await database.RecordFeedbackAsync(word.Id, WordFeedback.Known, now, new DateOnly(2026, 10, 17), 3.17, 5.28, 1, 1);

        await database.MarkReleasedAsync([word.Id], new DateOnly(2026, 10, 17));
        // A second call must not move the release date forward.
        await database.MarkReleasedAsync([word.Id], new DateOnly(2026, 10, 18));

        var due = Assert.Single(await database.GetDueReviewItemsAsync(new DateOnly(2026, 10, 18)));
        Assert.Equal(new DateOnly(2026, 10, 17), due.Card.ReleasedDate);
    }

    [Fact]
    public async Task CardStateRoundTripsThroughTheDatabase()
    {
        var database = Database;
        await database.InitializeAsync();
        await database.SeedWordBookAsync(
            "测试词书",
            "test fixture",
            [new StudyWord(0, 1, "alpha", "n.", "第一个")]);
        var word = Assert.Single(await database.GetNextUnstudiedWordsAsync(10));
        var now = new DateTimeOffset(2026, 10, 17, 9, 0, 0, TimeSpan.FromHours(8));

        await database.RecordFeedbackAsync(word.Id, WordFeedback.Known, now, new DateOnly(2026, 10, 20), 3.17, 5.28, 1, 1);

        var card = await database.GetCardAsync(word.Id);
        Assert.NotNull(card);
        Assert.Equal(3.17, card!.Stability, 3);
        Assert.Equal(5.28, card.Difficulty, 3);
        Assert.Equal(1, card.Repetitions);
        Assert.Equal(1, card.ConsecutiveKnown);
        Assert.Equal(new DateOnly(2026, 10, 17), card.LastReviewedDate);
        Assert.False(card.IsNewMemory);
    }

    [Fact]
    public async Task DailyNewWordTargetRoundTripsAndDefaultsToFifty()
    {
        var database = Database;
        await database.InitializeAsync();

        Assert.Equal(50, await database.GetDailyNewWordTargetAsync(new DateOnly(2026, 10, 17)));

        await database.SetDailyNewWordTargetAsync(new DateOnly(2026, 10, 17), 30);

        Assert.Equal(30, await database.GetDailyNewWordTargetAsync(new DateOnly(2026, 10, 17)));
        // Later days keep the most recent setting.
        Assert.Equal(30, await database.GetDailyNewWordTargetAsync(new DateOnly(2026, 11, 1)));
    }

    [Fact]
    public async Task InitializationIsIdempotent()
    {
        var database = Database;

        await database.InitializeAsync();
        await database.InitializeAsync();

        Assert.Equal(0, await database.GetReviewEventCountAsync());
    }

    [Fact]
    public async Task FreshDatabaseDashboardContainsZerosInsteadOfNulls()
    {
        var database = Database;
        await database.InitializeAsync();

        var dashboard = await database.GetDashboardAsync(new DateOnly(2026, 10, 17));

        Assert.Equal(new DashboardSnapshot(0, 0, 0, 0), dashboard);
    }
}
