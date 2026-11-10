using WordDrawer.Core;

namespace WordDrawer.Core.Tests;

public sealed class DrawerPlacementTests
{
    private const double AreaLeft = 0;
    private const double AreaWidth = 1920;
    private const double Width = 360;

    [Fact]
    public void Released_near_the_left_edge_snaps_left()
    {
        Assert.Equal(DockSide.Left, DrawerLayout.SnapTarget(20, Width, AreaLeft, AreaWidth));
    }

    [Fact]
    public void Released_near_the_right_edge_snaps_right()
    {
        Assert.Equal(DockSide.Right, DrawerLayout.SnapTarget(AreaWidth - Width - 12, Width, AreaLeft, AreaWidth));
    }

    [Fact]
    public void Released_in_the_middle_stays_free()
    {
        Assert.Null(DrawerLayout.SnapTarget(700, Width, AreaLeft, AreaWidth));
    }

    [Fact]
    public void Snap_distance_is_respected()
    {
        // 47 px from the edge is inside the 48 px threshold, 49 px is not.
        Assert.Equal(DockSide.Left, DrawerLayout.SnapTarget(47, Width, AreaLeft, AreaWidth));
        Assert.Null(DrawerLayout.SnapTarget(49, Width, AreaLeft, AreaWidth));
    }

    [Fact]
    public void Clamp_keeps_the_panel_inside_the_work_area()
    {
        Assert.Equal(AreaLeft, DrawerLayout.ClampWithin(-500, AreaLeft, AreaWidth, Width));
        Assert.Equal(AreaWidth - Width, DrawerLayout.ClampWithin(5000, AreaLeft, AreaWidth, Width));
        Assert.Equal(640, DrawerLayout.ClampWithin(640, AreaLeft, AreaWidth, Width));
    }
}
