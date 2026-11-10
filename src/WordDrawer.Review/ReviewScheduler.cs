namespace WordDrawer.Review;

/// <summary>
/// Builds the daily review queue and schedules cards with FSRS-5.
/// </summary>
public sealed class ReviewScheduler
{
    /// <summary>How many newly due words may enter the queue in one day. Backlog is not capped.</summary>
    public const int DefaultDailyReleaseLimit = 200;

    private readonly FsrsParameters _parameters;

    public ReviewScheduler(FsrsParameters? parameters = null)
    {
        _parameters = parameters ?? FsrsParameters.Default;
    }

    /// <summary>
    /// Returns the cards that should be studied today: everything already released
    /// (backlog, uncapped) plus up to <paramref name="dailyReleaseLimit"/> newly due cards.
    /// Newly released cards come back with <see cref="ReviewCard.ReleasedDate"/> set to
    /// <paramref name="today"/> so the caller can persist the release.
    /// </summary>
    public IReadOnlyList<ReviewCard> BuildQueue(
        IEnumerable<ReviewCard> cards,
        DateOnly today,
        int dailyReleaseLimit = DefaultDailyReleaseLimit)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(dailyReleaseLimit);

        var due = cards.Where(card => !card.Completed && card.DueDate <= today).ToArray();

        var backlog = due
            .Where(card => card.ReleasedDate is not null && card.ReleasedDate < today)
            .OrderBy(card => card.DueDate)
            .ThenByDescending(WeaknessScore)
            .ToArray();

        // Cards released earlier today belong to today's queue as well; they simply must
        // not consume another release slot.
        var releasedToday = due
            .Where(card => card.ReleasedDate == today)
            .OrderBy(card => card.DueDate)
            .ThenByDescending(WeaknessScore)
            .ToArray();

        var newlyReleased = due
            .Where(card => card.ReleasedDate is null)
            .OrderBy(card => card.DueDate)
            .ThenByDescending(WeaknessScore)
            .Take(Math.Max(0, dailyReleaseLimit - releasedToday.Length))
            .Select(card => card with { ReleasedDate = today })
            .ToArray();

        return backlog.Concat(releasedToday).Concat(newlyReleased).ToArray();
    }

    /// <summary>
    /// Applies FSRS-5 to a card. "认识" maps to Good (3) and "不认识" to Again (1).
    /// </summary>
    public ReviewSchedule Schedule(ReviewCard card, ReviewFeedback feedback, DateOnly today)
    {
        var w = _parameters.Weights;
        var grade = feedback == ReviewFeedback.Known ? 3d : 1d;

        double stability;
        double difficulty;

        if (card.IsNewMemory)
        {
            stability = Math.Clamp(w[(int)grade - 1], FsrsParameters.MinimumStability, FsrsParameters.MaximumStability);
            difficulty = InitialDifficulty(grade);
        }
        else
        {
            var lastReviewed = card.LastReviewedDate ?? today;
            var elapsedDays = Math.Max(0, today.DayNumber - lastReviewed.DayNumber);
            var previousStability = Math.Max(FsrsParameters.MinimumStability, card.Stability);
            var previousDifficulty = Math.Clamp(
                card.Difficulty <= 0 ? 5 : card.Difficulty,
                FsrsParameters.MinimumDifficulty,
                FsrsParameters.MaximumDifficulty);
            var retrievability = elapsedDays <= 0
                ? 1
                : _parameters.Retrievability(elapsedDays, previousStability);

            stability = grade == 1
                ? StabilityAfterForgetting(previousDifficulty, previousStability, retrievability)
                : elapsedDays <= 0
                    ? StabilityAfterSameDayReview(previousStability, grade)
                    : StabilityAfterRecall(previousDifficulty, previousStability, retrievability, grade);

            difficulty = NextDifficulty(previousDifficulty, grade);
        }

        stability = Math.Clamp(stability, FsrsParameters.MinimumStability, FsrsParameters.MaximumStability);

        var intervalDays = grade == 1
            ? 1
            : Math.Clamp(
                (int)Math.Round(_parameters.IntervalDays(stability)),
                1,
                (int)FsrsParameters.MaximumStability);

        var consecutiveKnown = feedback == ReviewFeedback.Known ? card.ConsecutiveKnown + 1 : 0;

        return new ReviewSchedule(
            today.AddDays(intervalDays),
            stability,
            consecutiveKnown,
            Math.Round(difficulty, 4),
            card.Repetitions + 1);
    }

    private double InitialDifficulty(double grade) =>
        Math.Clamp(
            _parameters.Weights[4] - Math.Exp(_parameters.Weights[5] * (grade - 1)) + 1,
            FsrsParameters.MinimumDifficulty,
            FsrsParameters.MaximumDifficulty);

    private double NextDifficulty(double difficulty, double grade)
    {
        var w = _parameters.Weights;
        var delta = -w[6] * (grade - 3);
        var damped = difficulty + delta * (10 - difficulty) / 9;
        var meanReversionTarget = InitialDifficulty(4);
        var reverted = w[7] * meanReversionTarget + (1 - w[7]) * damped;
        return Math.Clamp(reverted, FsrsParameters.MinimumDifficulty, FsrsParameters.MaximumDifficulty);
    }

    private double StabilityAfterRecall(double difficulty, double stability, double retrievability, double grade)
    {
        var w = _parameters.Weights;
        var increase =
            Math.Exp(w[8])
            * (11 - difficulty)
            * Math.Pow(stability, -w[9])
            * (Math.Exp(w[10] * (1 - retrievability)) - 1)
            * (grade == 2 ? w[15] : 1)
            * (grade == 4 ? w[16] : 1);

        // A successful review must never shorten the interval.
        return stability * (1 + Math.Max(0, increase));
    }

    private double StabilityAfterForgetting(double difficulty, double stability, double retrievability)
    {
        var w = _parameters.Weights;
        return w[11]
               * Math.Pow(difficulty, -w[12])
               * (Math.Pow(stability + 1, w[13]) - 1)
               * Math.Exp(w[14] * (1 - retrievability));
    }

    private double StabilityAfterSameDayReview(double stability, double grade)
    {
        var w = _parameters.Weights;
        var increase = Math.Exp(w[17] * (grade - 3 + w[18]));
        return stability * Math.Max(1, increase);
    }

    private static double WeaknessScore(ReviewCard card) =>
        card.UnknownCount * 2.5 - card.KnownCount - card.Stability * 0.15;
}
