using WordDrawer.Core;

namespace WordDrawer.Core.Tests;

public sealed class StudyClockTests
{
    private static readonly TimeSpan OneSecond = TimeSpan.FromSeconds(1);

    [Fact]
    public void Counts_ticks_while_the_user_is_active()
    {
        var clock = new StudyClock();

        for (var i = 0; i < 30; i++)
        {
            Assert.True(clock.Advance(OneSecond, TimeSpan.FromSeconds(5)));
        }

        Assert.Equal(30, clock.EffectiveSeconds);
        Assert.False(clock.IsIdle);
    }

    [Fact]
    public void Stops_after_three_minutes_without_input()
    {
        var clock = new StudyClock();

        Assert.True(clock.Advance(OneSecond, TimeSpan.FromSeconds(179)));
        Assert.False(clock.IsIdle);

        Assert.False(clock.Advance(OneSecond, TimeSpan.FromSeconds(181)));
        Assert.True(clock.IsIdle);
        Assert.Equal(1, clock.EffectiveSeconds);
    }

    [Fact]
    public void Resumes_on_the_next_input()
    {
        var clock = new StudyClock();
        clock.Advance(OneSecond, TimeSpan.FromMinutes(10));

        Assert.True(clock.Advance(OneSecond, TimeSpan.Zero));
        Assert.False(clock.IsIdle);
        Assert.Equal(1, clock.EffectiveSeconds);
    }

    [Fact]
    public void Reset_clears_the_accumulator()
    {
        var clock = new StudyClock();
        clock.Advance(TimeSpan.FromSeconds(90), TimeSpan.Zero);
        clock.Reset();

        Assert.Equal(0, clock.EffectiveSeconds);
    }
}
