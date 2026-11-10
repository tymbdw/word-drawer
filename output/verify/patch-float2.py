import io

p = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
s = io.open(p, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global s
    assert s.count(old) == n, (s.count(old), old[:70])
    s = s.replace(old, new)


# 1. RefreshBackdrop can be told which floating rectangle to sample
rep(
    """    private void RefreshBackdrop()
    {
        var area = WorkArea;
        Rect dip;
        if (_isFloating)
        {
            dip = new Rect(Left + ShadowInset, Top + ShadowInset, ContentWidth, ContentHeight);
        }""",
    """    private void RefreshBackdrop(Rect? floatingRect = null)
    {
        var area = WorkArea;
        Rect dip;
        if (_isFloating)
        {
            dip = floatingRect ?? new Rect(Left + ShadowInset, Top + ShadowInset, ContentWidth, ContentHeight);
        }""",
)

# 2. drop the opacity trick: sleeping on the dispatcher means the window never repaints,
#    so the capture ends up containing the drawer itself.
rep(
    """        var concealed = (int)Math.Round(8 * dpi.DpiScaleX);

        ImageSource? glass;
        if (_isFloating)
        {
            // The window sits exactly on the rectangle we need to sample, so hide it for a
            // frame instead of moving it off screen.
            var previous = Opacity;
            Opacity = 0;
            Thread.Sleep(45);
            try
            {
                glass = ScreenBackdrop.Compose(physical, concealed, EffectiveGlassAlpha, _glassR, _glassG, _glassB);
            }
            finally
            {
                Opacity = previous;
            }
        }
        else
        {
            glass = ScreenBackdrop.Compose(physical, concealed, EffectiveGlassAlpha, _glassR, _glassG, _glassB);
        }""",
    """        var concealed = (int)Math.Round(8 * dpi.DpiScaleX);

        // The caller must make sure the window is not covering the rectangle it asks for.
        var glass = ScreenBackdrop.Compose(physical, concealed, EffectiveGlassAlpha, _glassR, _glassG, _glassB);""",
)

# 3. helper that parks the window, samples, then returns
rep(
    """    private void ShowShadows(bool visible)""",
    """    /// <summary>
    /// Samples the desktop for a floating rectangle. The window is moved off screen first:
    /// fading it out does not work because the blur capture happens on the UI thread, which
    /// cannot repaint while it blocks.
    /// </summary>
    private void RefreshFloatingBackdrop(double contentLeft, double contentTop)
    {
        var area = WorkArea;
        var parkLeft = area.Left - ContentWidth - ShadowInset * 2;
        MoveTo(parkLeft, animate: false);
        RefreshBackdrop(new Rect(contentLeft, contentTop, ContentWidth, ContentHeight));
    }

    private void ShowShadows(bool visible)""",
)

# 4. float: park, sample, come back
rep(
    """        var left = DrawerLayout.ClampWithin(Left + ShadowInset, area.Left, area.Width, ContentWidth);
        var top = DrawerLayout.ClampWithin(contentTop, area.Top, area.Height, ContentHeight);
        MoveTo(left - ShadowInset, animate: false);
        Top = top - ShadowInset;

        ShowShadows(true);
        RefreshBackdrop();""",
    """        var left = DrawerLayout.ClampWithin(Left + ShadowInset, area.Left, area.Width, ContentWidth);
        var top = DrawerLayout.ClampWithin(contentTop, area.Top, area.Height, ContentHeight);

        ShowShadows(true);
        RefreshFloatingBackdrop(left, top);
        MoveTo(left - ShadowInset, animate: false);
        Top = top - ShadowInset;""",
)

# 5. restoring a saved position on startup
rep(
    """            MoveTo(DrawerLayout.ClampWithin(x, area.Left, area.Width, ContentWidth) - ShadowInset, animate: false);
            Top = DrawerLayout.ClampWithin(y, area.Top, area.Height, ContentHeight) - ShadowInset;
            ShowShadows(true);
            RefreshBackdrop();""",
    """            var left = DrawerLayout.ClampWithin(x, area.Left, area.Width, ContentWidth);
            var top = DrawerLayout.ClampWithin(y, area.Top, area.Height, ContentHeight);
            ShowShadows(true);
            RefreshFloatingBackdrop(left, top);
            MoveTo(left - ShadowInset, animate: false);
            Top = top - ShadowInset;""",
)

# 6. revealing while floating
rep(
    """        if (_isFloating)
        {
            _isHidden = false;
            ShowShadows(true);
            RefreshBackdrop();
            return;
        }""",
    """        if (_isFloating)
        {
            _isHidden = false;
            ShowShadows(true);
            var left = Left + ShadowInset;
            var top = Top + ShadowInset;
            RefreshFloatingBackdrop(left, top);
            MoveTo(left - ShadowInset, animate: false);
            Top = top - ShadowInset;
            return;
        }""",
)

io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("floating sample fixed")
