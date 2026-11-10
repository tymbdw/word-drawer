namespace WordDrawer.Core;

public static class DrawerLayout
{
    public const double DefaultSnapDistance = 48;

    /// <summary>
    /// Distance kept between the drawer and the screen edge when it is open, so the
    /// rounded corners (and a future drop shadow) are not cut off by the display edge.
    /// </summary>
    public const double DefaultEdgeGap = 28;

    public static double VisibleLeft(
        DockSide side,
        double workAreaLeft,
        double workAreaWidth,
        double windowWidth,
        double edgeGap = 0) =>
        side == DockSide.Left
            ? workAreaLeft + edgeGap
            : workAreaLeft + workAreaWidth - windowWidth - edgeGap;

    public static double HiddenLeft(
        DockSide side,
        double workAreaLeft,
        double workAreaWidth,
        double windowWidth,
        double revealStripWidth = 8) =>
        side == DockSide.Left
            ? workAreaLeft - windowWidth + revealStripWidth
            : workAreaLeft + workAreaWidth - revealStripWidth;

    /// <summary>
    /// Decides where a dragged drawer should settle: a side when it was released close to
    /// the left or right edge of the work area, otherwise null (it stays where it is).
    /// </summary>
    public static DockSide? SnapTarget(
        double contentLeft,
        double contentWidth,
        double areaLeft,
        double areaWidth,
        double snapDistance = DefaultSnapDistance)
    {
        if (contentLeft - areaLeft <= snapDistance)
        {
            return DockSide.Left;
        }

        var gapRight = areaLeft + areaWidth - (contentLeft + contentWidth);
        if (gapRight <= snapDistance)
        {
            return DockSide.Right;
        }

        return null;
    }

    /// <summary>Keeps a floating drawer fully inside the work area.</summary>
    public static double ClampWithin(double value, double origin, double extent, double size)
    {
        if (extent <= size)
        {
            return origin;
        }

        return Math.Clamp(value, origin, origin + extent - size);
    }
}
