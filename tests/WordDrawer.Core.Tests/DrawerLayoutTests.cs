using WordDrawer.Core;

namespace WordDrawer.Core.Tests;

public sealed class DrawerLayoutTests
{
    [Theory]
    [InlineData(DockSide.Left, 0, 1920, 360, 0)]
    [InlineData(DockSide.Right, 0, 1920, 360, 1560)]
    [InlineData(DockSide.Left, 1920, 2560, 360, 1920)]
    [InlineData(DockSide.Right, 1920, 2560, 360, 4120)]
    public void VisiblePositionRespectsMonitorWorkArea(
        DockSide side,
        double left,
        double width,
        double windowWidth,
        double expected)
    {
        Assert.Equal(expected, DrawerLayout.VisibleLeft(side, left, width, windowWidth));
    }

    [Theory]
    [InlineData(DockSide.Left, 0, 1920, 360, 28)]
    [InlineData(DockSide.Right, 0, 1920, 360, 1532)]
    [InlineData(DockSide.Left, 1920, 2560, 360, 1948)]
    [InlineData(DockSide.Right, 1920, 2560, 360, 4092)]
    public void VisiblePositionKeepsEdgeGapSoRoundedCornersStayVisible(
        DockSide side,
        double left,
        double width,
        double windowWidth,
        double expected)
    {
        Assert.Equal(expected, DrawerLayout.VisibleLeft(side, left, width, windowWidth, DrawerLayout.DefaultEdgeGap));
    }

    [Theory]
    [InlineData(DockSide.Left, 0, 1920, 360, -352)]
    [InlineData(DockSide.Right, 0, 1920, 360, 1912)]
    public void HiddenPositionLeavesEightPixelTriggerStrip(
        DockSide side,
        double left,
        double width,
        double windowWidth,
        double expected)
    {
        Assert.Equal(expected, DrawerLayout.HiddenLeft(side, left, width, windowWidth));
    }
}
