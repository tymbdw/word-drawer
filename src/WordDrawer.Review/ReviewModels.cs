namespace WordDrawer.Review;

public enum ReviewFeedback
{
    Unknown,
    Known
}

/// <summary>
/// One word's memory state. <paramref name="Difficulty"/>, <paramref name="LastReviewedDate"/>
/// and <paramref name="Repetitions"/> are trailing optional members so the positional
/// constructor used by older call sites and tests keeps compiling.
/// </summary>
public sealed record ReviewCard(
    long WordId,
    DateOnly DueDate,
    DateOnly? ReleasedDate,
    int KnownCount,
    int UnknownCount,
    int ConsecutiveKnown,
    double Stability,
    bool Completed = false,
    double Difficulty = 0,
    DateOnly? LastReviewedDate = null,
    int Repetitions = 0)
{
    /// <summary>True when FSRS has no memory state yet, i.e. the word was never rated.</summary>
    public bool IsNewMemory => Repetitions <= 0 && Difficulty <= 0 && LastReviewedDate is null;
}

public sealed record ReviewSchedule(
    DateOnly NextDueDate,
    double Stability,
    int ConsecutiveKnown,
    double Difficulty,
    int Repetitions);

/// <summary>A due word together with the memory state needed to schedule it.</summary>
public sealed record ReviewQueueItem(
    long WordId,
    int Sequence,
    string English,
    string PartOfSpeech,
    string Meaning,
    ReviewCard Card);
