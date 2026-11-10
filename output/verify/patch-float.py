import io

p = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
s = io.open(p, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global s
    assert s.count(old) == n, (s.count(old), old[:60])
    s = s.replace(old, new)


rep(
    "    private readonly StudyClock _clock",
    """    private const double SnapDistance = DrawerLayout.DefaultSnapDistance;
    private bool _isFloating;
    private readonly StudyClock _clock""",
)

rep(
    """        ApplyTheme();
        UpdateSettingsUi();

        // ApplyTheme leaves a flat fallback brush; re-sample so the frosted image is back
        // before the drawer slides in.
        RevealWithFreshBackdrop();""",
    """        ApplyTheme();
        UpdateSettingsUi();

        var mode = await _database.GetSettingAsync("DockMode");
        if (string.Equals(mode, "free", StringComparison.Ordinal))
        {
            _isFloating = true;
            var area = WorkArea;
            var x = double.TryParse(await _database.GetSettingAsync("FreeX"), out var fx) ? fx : area.Left + 120;
            var y = double.TryParse(await _database.GetSettingAsync("FreeY"), out var fy) ? fy : area.Top + 120;
            MoveTo(DrawerLayout.ClampWithin(x, area.Left, area.Width, ContentWidth) - ShadowInset, animate: false);
            Top = DrawerLayout.ClampWithin(y, area.Top, area.Height, ContentHeight) - ShadowInset;
            ShowShadows(true);
            RefreshBackdrop();
            StatusText.Text = "已恢复上次位置";
            return;
        }

        // ApplyTheme leaves a flat fallback brush; re-sample so the frosted image is back
        // before the drawer slides in.
        RevealWithFreshBackdrop();""",
)

rep(
    """        // Hide the halo first: part of it would land inside the sampled rectangle.
        WindowShadowFar.Visibility = Visibility.Collapsed;
        WindowShadowNear.Visibility = Visibility.Collapsed;
        MoveTo(DrawerLayout.HiddenLeft(_dockSide, WorkArea.Left, WorkArea.Width, ContentWidth) - ShadowInset, animate: false);""",
    """        if (_isFloating)
        {
            _isHidden = false;
            ShowShadows(true);
            RefreshBackdrop();
            return;
        }

        // Hide the halo first: part of it would land inside the sampled rectangle.
        WindowShadowFar.Visibility = Visibility.Collapsed;
        WindowShadowNear.Visibility = Visibility.Collapsed;
        MoveTo(DrawerLayout.HiddenLeft(_dockSide, WorkArea.Left, WorkArea.Width, ContentWidth) - ShadowInset, animate: false);""",
)

rep(
    """        var area = WorkArea;
        var top = area.Top + Math.Max(12, (area.Height - ContentHeight) / 2);
        var left = DrawerLayout.VisibleLeft(_dockSide, area.Left, area.Width, ContentWidth, EdgeGap);
        var dip = new Rect(left, top, ContentWidth, ContentHeight);""",
    """        var area = WorkArea;
        Rect dip;
        if (_isFloating)
        {
            dip = new Rect(Left + ShadowInset, Top + ShadowInset, ContentWidth, ContentHeight);
        }
        else
        {
            var dockedTop = area.Top + Math.Max(12, (area.Height - ContentHeight) / 2);
            var dockedLeft = DrawerLayout.VisibleLeft(_dockSide, area.Left, area.Width, ContentWidth, EdgeGap);
            dip = new Rect(dockedLeft, dockedTop, ContentWidth, ContentHeight);
        }""",
)

rep(
    """        var concealed = (int)Math.Round(8 * dpi.DpiScaleX);
        var glass = ScreenBackdrop.Compose(physical, concealed, EffectiveGlassAlpha, _glassR, _glassG, _glassB);""",
    """        var concealed = (int)Math.Round(8 * dpi.DpiScaleX);

        BitmapSource? glass;
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
)

rep(
    """    private void Header_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
            var area = WorkArea;
            _dockSide = Left + ShadowInset + ContentWidth / 2 < area.Left + area.Width / 2 ? DockSide.Left : DockSide.Right;
            RevealWithFreshBackdrop();
        }
    }""",
    """    private void Header_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState != MouseButtonState.Pressed)
        {
            return;
        }

        DragMove();
        var area = WorkArea;
        var contentLeft = Left + ShadowInset;
        var contentTop = Top + ShadowInset;
        var target = DrawerLayout.SnapTarget(contentLeft, ContentWidth, area.Left, area.Width, SnapDistance);

        if (target is { } side)
        {
            _dockSide = side;
            _isFloating = false;
            _ = PersistPlacementAsync();
            RevealWithFreshBackdrop();
            return;
        }

        FloatInPlace(contentTop);
    }

    /// <summary>Leaves the drawer where it was dropped and remembers that spot.</summary>
    private void FloatInPlace(double contentTop)
    {
        var area = WorkArea;
        _isFloating = true;
        _isHidden = false;

        var left = DrawerLayout.ClampWithin(Left + ShadowInset, area.Left, area.Width, ContentWidth);
        var top = DrawerLayout.ClampWithin(contentTop, area.Top, area.Height, ContentHeight);
        MoveTo(left - ShadowInset, animate: false);
        Top = top - ShadowInset;

        ShowShadows(true);
        RefreshBackdrop();
        StatusText.Text = "已放置在当前位置 · 拖到屏幕边缘可贴边";
        _ = PersistPlacementAsync();
    }

    private async Task PersistPlacementAsync()
    {
        try
        {
            await _database.SetSettingAsync("DockMode", _isFloating ? "free" : "docked");
            if (_isFloating)
            {
                await _database.SetSettingAsync("FreeX", (Left + ShadowInset).ToString(CultureInfo.InvariantCulture));
                await _database.SetSettingAsync("FreeY", (Top + ShadowInset).ToString(CultureInfo.InvariantCulture));
            }
        }
        catch (Exception exception)
        {
            StatusText.Text = $"保存位置失败：{exception.Message}";
        }
    }

    private void ShowShadows(bool visible)
    {
        var state = visible ? Visibility.Visible : Visibility.Collapsed;
        WindowShadowFar.Visibility = state;
        WindowShadowNear.Visibility = state;
    }""",
)

rep(
    """        if (!_isPinned && _autoHide)
        {
            _hideTimer.Stop();
            _hideTimer.Start();
        }""",
    """        if (!_isPinned && _autoHide && !_isFloating)
        {
            _hideTimer.Stop();
            _hideTimer.Start();
        }""",
)

rep(
    """        if (_isPinned)
        {
            DockToCurrentSide(animate: true);
        }""",
    """        if (_isPinned && !_isFloating)
        {
            DockToCurrentSide(animate: true);
        }""",
)

rep(
    """        _dockSide = _dockSide == DockSide.Left ? DockSide.Right : DockSide.Left;
        RevealWithFreshBackdrop();""",
    """        _dockSide = _dockSide == DockSide.Left ? DockSide.Right : DockSide.Left;
        _isFloating = false;
        _ = PersistPlacementAsync();
        RevealWithFreshBackdrop();""",
)

io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("app patched")
