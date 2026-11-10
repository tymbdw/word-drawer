namespace WordDrawer.Core;

/// <summary>
/// Counts effective study time. Time only accrues while the user is actually there:
/// once the keyboard and mouse have been untouched for the idle threshold the clock
/// stops, and it resumes on the next input.
/// </summary>
public sealed class StudyClock
{
    public static readonly TimeSpan DefaultIdleThreshold = TimeSpan.FromMinutes(3);

    private readonly TimeSpan _idleThreshold;

    public StudyClock(TimeSpan? idleThreshold = null)
    {
        _idleThreshold = idleThreshold ?? DefaultIdleThreshold;
    }

    public long EffectiveSeconds { get; private set; }

    public bool IsIdle { get; private set; }

    /// <summary>Feeds one tick. Returns true when the tick counted towards the session.</summary>
    public bool Advance(TimeSpan elapsed, TimeSpan sinceLastInput)
    {
        IsIdle = sinceLastInput > _idleThreshold;
        if (IsIdle)
        {
            return false;
        }

        EffectiveSeconds += (long)Math.Round(elapsed.TotalSeconds, MidpointRounding.AwayFromZero);
        return true;
    }

    public void Reset()
    {
        EffectiveSeconds = 0;
        IsIdle = false;
    }
}
