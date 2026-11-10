import io

cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"

c = io.open(cs, encoding="utf-8-sig").read()


def repc(old, new, n=1):
    global c
    assert c.count(old) == n, (c.count(old), old[:70])
    c = c.replace(old, new)


# state for the manual drag
repc(
    '    private string _activeBookName = "—";',
    '''    private string _activeBookName = "—";
    private Drawing.Bitmap? _dragPlate;
    private Point _dragOrigin;
    private double _dragStartLeft;
    private double _dragStartTop;
    private bool _dragging;
    private long _lastDragFrame;''',
)

old_down = '''        DragMove();
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
    }'''

new_down = '''        // Snapshot the desktop once, with this window invisible, so every mouse move can
        // re-cut the glass out of the plate instead of hitting the screen again.
        var previousOpacity = Opacity;
        Opacity = 0;
        Dispatcher.Invoke(() => { }, DispatcherPriority.Render);
        _dragPlate = ScreenBackdrop.CaptureScreen();
        Opacity = previousOpacity;

        if (_dragPlate is null)
        {
            return;
        }

        var cursor = System.Windows.Forms.Control.MousePosition;
        var dpi = VisualTreeHelper.GetDpi(this);
        _dragOrigin = new Point(cursor.X / dpi.DpiScaleX, cursor.Y / dpi.DpiScaleY);
        _dragStartLeft = Left;
        _dragStartTop = Top;
        _dragging = true;
        Mouse.Capture((IInputElement)sender);
    }

    /// <summary>Moves the window with the cursor and rebuilds the glass from the cached plate.</summary>
    private void Header_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_dragging || e.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }

        var cursor = System.Windows.Forms.Control.MousePosition;
        var dpi = VisualTreeHelper.GetDpi(this);
        var pointer = new Point(cursor.X / dpi.DpiScaleX, cursor.Y / dpi.DpiScaleY);

        Left = _dragStartLeft + (pointer.X - _dragOrigin.X);
        Top = _dragStartTop + (pointer.Y - _dragOrigin.Y);

        var now = Environment.TickCount64;
        if (now - _lastDragFrame < 12)
        {
            return;
        }

        _lastDragFrame = now;
        RefreshBackdropFromPlate();
    }

    private void Header_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }

        _dragging = false;
        Mouse.Capture(null);
        _dragPlate?.Dispose();
        _dragPlate = null;

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

    /// <summary>Cheap glass refresh: cut the plate at the current position, blur, tint.</summary>
    private void RefreshBackdropFromPlate()
    {
        if (_dragPlate is null)
        {
            return;
        }

        var dpi = VisualTreeHelper.GetDpi(this);
        var dip = new Rect(Left + ShadowInset, Top + ShadowInset, ContentWidth, ContentHeight);
        var physical = new Rect(
            dip.X * dpi.DpiScaleX,
            dip.Y * dpi.DpiScaleY,
            dip.Width * dpi.DpiScaleX,
            dip.Height * dpi.DpiScaleY);

        using var crop = ScreenBackdrop.Cropplate(_dragPlate, physical);
        var glass = ScreenBackdrop.ComposeFrom(crop, EffectiveGlassAlpha, _glassR, _glassG, _glassB);
        if (glass is null)
        {
            return;
        }

        var brush = new ImageBrush(glass) { Stretch = Stretch.Fill };
        brush.Freeze();
        GlassSurface.Background = brush;
    }'''

repc(old_down, new_down)
io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("drag rewritten")

s = io.open(xaml, encoding="utf-8-sig").read()
old = 'Background="Transparent" MouseLeftButtonDown="Header_MouseLeftButtonDown">'
new = ('Background="Transparent" MouseLeftButtonDown="Header_MouseLeftButtonDown"\n'
       '                        MouseMove="Header_MouseMove" MouseLeftButtonUp="Header_MouseLeftButtonUp">')
assert s.count(old) == 1
s = s.replace(old, new)
io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("header wired")
