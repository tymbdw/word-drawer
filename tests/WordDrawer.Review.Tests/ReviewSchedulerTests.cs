using WordDrawer.Review;

namespace WordDrawer.Review.Tests;

public sealed class ReviewSchedulerTests
{
    private static readonly DateOnly Today = new(2026, 10, 17);
    private readonly ReviewScheduler _scheduler = new();

    [Fact]
    public void QueueKeepsAllBacklogAndCapsOnlyNewReleases()
    {
        var backlog = Enumerable.Range(1, 35)
            .Select(i => Card(i, Today.AddDays(-2), Today.AddDays(-1)));
        var unreleased = Enumerable.Range(1000, 500)
            .Select(i => Card(i, Today, null));

        var queue = _scheduler.BuildQueue(backlog.Concat(unreleased), Today);

        Assert.Equal(235, queue.Count);
        Assert.Equal(35, queue.Count(card => card.ReleasedDate < Today));
        Assert.Equal(200, queue.Count(card => card.ReleasedDate == Today));
    }

    [Fact]
    public void CardsAlreadyReleasedTodayDoNotConsumeTodaySReleaseBudget()
    {
        var releasedToday = Enumerable.Range(1, 10).Select(i => Card(i, Today, Today));
        var newlyDue = Enumerable.Range(100, 30).Select(i => Card(i, Today, null));

        var queue = _scheduler.BuildQueue(releasedToday.Concat(newlyDue), Today, dailyReleaseLimit: 15);

        Assert.Equal(15, queue.Count);
        Assert.Equal(10, queue.Count(card => card.WordId < 100));
        Assert.Equal(5, queue.Count(card => card.WordId >= 100));
    }

    [Fact]
    public void QueuePrioritizesOverdueCardsBeforeWeakness()
    {
        var cards = new[]
        {
            Card(1, Today, null, unknown: 20),
            Card(2, Today.AddDays(-4), null),
        };

        var queue = _scheduler.BuildQueue(cards, Today, 1);

        Assert.Equal(2, queue.Single().WordId);
    }

    [Fact]
    public void CompletedCardsAreExcluded()
    {
        var cards = new[] { Card(1, Today, null) with { Completed = true } };

        Assert.Empty(_scheduler.BuildQueue(cards, Today));
    }

    [Fact]
    public void FirstKnownReviewUsesFsrsInitialStability()
    {
        var result = _scheduler.Schedule(Card(1, Today, null), ReviewFeedback.Known, Today);

        // S0(Good) = w2 = 3.173, D0(Good) = w4 - e^(2*w5) + 1 = 5.2824
        Assert.Equal(3.173, result.Stability, 6);
        Assert.Equal(5.2824, result.Difficulty, 3);
        Assert.Equal(Today.AddDays(3), result.NextDueDate);
        Assert.Equal(1, result.Repetitions);
        Assert.Equal(1, result.ConsecutiveKnown);
    }

    [Fact]
    public void FirstUnknownReviewSchedulesTomorrowWithAgainStability()
    {
        var result = _scheduler.Schedule(Card(1, Today, null), ReviewFeedback.Unknown, Today);

        // S0(Again) = w0 = 0.40255, D0(Again) = w4 = 7.1949
        Assert.Equal(0.40255, result.Stability, 6);
        Assert.Equal(7.1949, result.Difficulty, 3);
        Assert.Equal(Today.AddDays(1), result.NextDueDate);
    }

    [Fact]
    public void KnownReviewAfterTheDueDateGrowsTheInterval()
    {
        var first = _scheduler.Schedule(Card(1, Today, null), ReviewFeedback.Known, Today);
        var reviewed = Card(1, first.NextDueDate, Today) with
        {
            Stability = first.Stability,
            Difficulty = first.Difficulty,
            LastReviewedDate = Today,
            Repetitions = first.Repetitions,
            ConsecutiveKnown = first.ConsecutiveKnown
        };

        var second = _scheduler.Schedule(reviewed, ReviewFeedback.Known, first.NextDueDate);

        Assert.True(second.Stability > first.Stability);
        Assert.True(second.NextDueDate > first.NextDueDate);
        Assert.Equal(2, second.Repetitions);
        Assert.Equal(2, second.ConsecutiveKnown);
    }

    [Fact]
    public void UnknownReviewDropsStabilityAndResetsTheStreak()
    {
        var card = Card(1, Today, Today) with
        {
            Stability = 30,
            Difficulty = 5,
            LastReviewedDate = Today.AddDays(-20),
            Repetitions = 4,
            ConsecutiveKnown = 4
        };

        var result = _scheduler.Schedule(card, ReviewFeedback.Unknown, Today);

        Assert.True(result.Stability < card.Stability);
        Assert.Equal(Today.AddDays(1), result.NextDueDate);
        Assert.Equal(0, result.ConsecutiveKnown);
        Assert.Equal(5, result.Repetitions);
    }

    [Fact]
    public void SameDayReviewNeverShrinksStability()
    {
        var card = Card(1, Today, Today) with
        {
            Stability = 8,
            Difficulty = 5,
            LastReviewedDate = Today,
            Repetitions = 2
        };

        var result = _scheduler.Schedule(card, ReviewFeedback.Known, Today);

        // same-day recall: S' = S * exp(w17 * (G - 3 + w18)) = 8 * exp(0.51655 * 0.6621) = 11.26
        Assert.Equal(11.2615, result.Stability, 3);
        Assert.True(result.Stability >= card.Stability);
        Assert.Equal(Today.AddDays(11), result.NextDueDate);
    }

    [Fact]
    public void DifficultyStaysInsideTheFsrsBounds()
    {
        var card = Card(1, Today, Today);
        var today = Today;

        for (var i = 0; i < 60; i++)
        {
            var feedback = i % 3 == 0 ? ReviewFeedback.Unknown : ReviewFeedback.Known;
            var result = _scheduler.Schedule(card, feedback, today);
            Assert.InRange(result.Difficulty, 1, 10);
            Assert.InRange(result.Stability, 0.1, 36500);

            card = card with
            {
                Stability = result.Stability,
                Difficulty = result.Difficulty,
                LastReviewedDate = today,
                Repetitions = result.Repetitions
            };
            today = result.NextDueDate;
        }
    }

    [Fact]
    public void RetrievabilityIsNinetyPercentAtStability()
    {
        var parameters = FsrsParameters.Default;

        Assert.Equal(0.9, parameters.Retrievability(parameters.IntervalDays(10), 10), 6);
        Assert.Equal(1, parameters.Retrievability(0, 10), 6);
    }

    private static ReviewCard Card(
        long id,
        DateOnly due,
        DateOnly? released,
        int known = 0,
        int unknown = 0) =>
        new(id, due, released, known, unknown, 0, 1);
}
