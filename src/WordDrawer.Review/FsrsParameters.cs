namespace WordDrawer.Review;

/// <summary>
/// FSRS-5 memory model with the default parameters published in the FSRS wiki:
/// https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm
/// Stability (S) is the interval at which recall probability is 90%.
/// </summary>
public sealed class FsrsParameters
{
    /// <summary>Weights w0..w18. Do not reorder.</summary>
    public static readonly double[] DefaultWeights =
    [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575,
        0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621
    ];

    /// <summary>Forgetting-curve decay for FSRS-4.5 and later.</summary>
    public const double Decay = -0.5;

    /// <summary>Forgetting-curve factor, chosen so R(t=S, S) = 0.9.</summary>
    public const double Factor = 19.0 / 81.0;

    public const double MinimumStability = 0.1;
    public const double MaximumStability = 36500;
    public const double MinimumDifficulty = 1;
    public const double MaximumDifficulty = 10;

    public FsrsParameters(double[]? weights = null, double desiredRetention = 0.9)
    {
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(desiredRetention, 0);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(desiredRetention, 1);

        Weights = weights ?? DefaultWeights;
        if (Weights.Length != 19)
        {
            throw new ArgumentException("FSRS-5 requires exactly 19 weights.", nameof(weights));
        }

        DesiredRetention = desiredRetention;
    }

    public static FsrsParameters Default { get; } = new();

    public double[] Weights { get; }

    public double DesiredRetention { get; }

    /// <summary>Probability of recall after <paramref name="elapsedDays"/> with the given stability.</summary>
    public double Retrievability(double elapsedDays, double stability)
    {
        if (stability <= 0)
        {
            return 0;
        }

        return Math.Pow(1 + Factor * Math.Max(0, elapsedDays) / stability, Decay);
    }

    /// <summary>Interval whose predicted recall probability equals the desired retention.</summary>
    public double IntervalDays(double stability) =>
        stability / Factor * (Math.Pow(DesiredRetention, 1 / Decay) - 1);
}
