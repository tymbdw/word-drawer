import io

p = r"D:\Window Word\src\WordDrawer.App\ScreenBackdrop.cs"
s = io.open(p, encoding="utf-8-sig").read()

old_head = '''    public static ImageSource? Compose(Rect physicalRect, int concealedRightPixels, byte glassAlpha, byte tintR, byte tintG, byte tintB)
    {
        var width = (int)Math.Round(physicalRect.Width);
        var height = (int)Math.Round(physicalRect.Height);
        if (width < 8 || height < 8)
        {
            return null;
        }

        using var captured = new Drawing.Bitmap(width, height, DrawingImaging.PixelFormat.Format32bppArgb);
        using (var graphics = Drawing.Graphics.FromImage(captured))
        {
            var screenDc = GetDC(IntPtr.Zero);
            var targetDc = graphics.GetHdc();
            try
            {
                BitBlt(
                    targetDc,
                    0,
                    0,
                    width,
                    height,
                    screenDc,
                    (int)Math.Round(physicalRect.X),
                    (int)Math.Round(physicalRect.Y),
                    SrcCopy);
            }
            finally
            {
                graphics.ReleaseHdc(targetDc);
                ReleaseDC(IntPtr.Zero, screenDc);
            }

            // The collapsed drawer keeps an 8px trigger strip on screen; smear the
            // neighbouring column across it so our own glass is not baked in.
            if (concealedRightPixels > 0 && concealedRightPixels < width - 2)
            {
                var source = new Drawing.Rectangle(width - concealedRightPixels - 1, 0, 1, height);
                var target = new Drawing.Rectangle(width - concealedRightPixels, 0, concealedRightPixels, height);
                graphics.DrawImage(captured, target, source, Drawing.GraphicsUnit.Pixel);
            }
        }
'''

new_head = '''    public static ImageSource? Compose(Rect physicalRect, int concealedRightPixels, byte glassAlpha, byte tintR, byte tintG, byte tintB)
    {
        using var captured = CaptureRegion(physicalRect, concealedRightPixels);
        return captured is null
            ? null
            : ComposeFrom(captured, glassAlpha, tintR, tintG, tintB);
    }

    /// <summary>Grabs one screen rectangle as a bitmap, or null when the rectangle is degenerate.</summary>
    public static Drawing.Bitmap? CaptureRegion(Rect physicalRect, int concealedRightPixels)
    {
        var width = (int)Math.Round(physicalRect.Width);
        var height = (int)Math.Round(physicalRect.Height);
        if (width < 8 || height < 8)
        {
            return null;
        }

        var captured = new Drawing.Bitmap(width, height, DrawingImaging.PixelFormat.Format32bppArgb);
        using var graphics = Drawing.Graphics.FromImage(captured);
        var screenDc = GetDC(IntPtr.Zero);
        var targetDc = graphics.GetHdc();
        try
        {
            BitBlt(
                targetDc,
                0,
                0,
                width,
                height,
                screenDc,
                (int)Math.Round(physicalRect.X),
                (int)Math.Round(physicalRect.Y),
                SrcCopy);
        }
        finally
        {
            graphics.ReleaseHdc(targetDc);
            ReleaseDC(IntPtr.Zero, screenDc);
        }

        // The collapsed drawer keeps an 8px trigger strip on screen; smear the
        // neighbouring column across it so our own glass is not baked in.
        if (concealedRightPixels > 0 && concealedRightPixels < width - 2)
        {
            var source = new Drawing.Rectangle(width - concealedRightPixels - 1, 0, 1, height);
            var target = new Drawing.Rectangle(width - concealedRightPixels, 0, concealedRightPixels, height);
            graphics.DrawImage(captured, target, source, Drawing.GraphicsUnit.Pixel);
        }

        return captured;
    }

    /// <summary>
    /// Snapshot of the whole primary screen. Dragging re-uses this plate instead of hitting
    /// the screen again on every mouse move.
    /// </summary>
    public static Drawing.Bitmap? CaptureScreen() =>
        CaptureRegion(new Rect(0, 0, GetSystemMetrics(SmCxScreen), GetSystemMetrics(SmCyScreen)), 0);

    /// <summary>Cuts the requested rectangle out of the plate, clamping at the screen edges.</summary>
    public static Drawing.Bitmap Cropplate(Drawing.Bitmap plate, Rect physicalRect)
    {
        var width = Math.Max(8, (int)Math.Round(physicalRect.Width));
        var height = Math.Max(8, (int)Math.Round(physicalRect.Height));
        var crop = new Drawing.Bitmap(width, height, DrawingImaging.PixelFormat.Format32bppArgb);

        using var graphics = Drawing.Graphics.FromImage(crop);
        var source = new Drawing.Rectangle(
            (int)Math.Round(physicalRect.X),
            (int)Math.Round(physicalRect.Y),
            width,
            height);

        // Anything outside the plate is mirrored from the nearest edge pixel-row.
        graphics.Clear(Drawing.Color.FromArgb(255, 0x1b, 0x28, 0x36));
        var usable = Drawing.Rectangle.Intersect(source, new Drawing.Rectangle(0, 0, plate.Width, plate.Height));
        if (usable.Width > 0 && usable.Height > 0)
        {
            graphics.DrawImage(
                plate,
                new Drawing.Rectangle(usable.Left - source.Left, usable.Top - source.Top, usable.Width, usable.Height),
                usable,
                Drawing.GraphicsUnit.Pixel);
        }

        return crop;
    }

    /// <summary>Blur, tint and encode a rectangle that was already captured.</summary>
    public static ImageSource? ComposeFrom(Drawing.Bitmap captured, byte glassAlpha, byte tintR, byte tintG, byte tintB)
    {
        var width = captured.Width;
        var height = captured.Height;
'''

assert s.count(old_head) == 1
s = s.replace(old_head, new_head)

# ComposeFrom must not reference the removed local width/height before it is declared,
# and the P/Invoke for the screen size is missing.
if "GetSystemMetrics" not in s.split("public static class")[0]:
    s = s.replace(
        "    private static extern bool BitBlt(",
        "    [DllImport(\"user32.dll\")]\n    private static extern int GetSystemMetrics(int index);\n\n    private const int SmCxScreen = 0;\n    private const int SmCyScreen = 1;\n\n    [DllImport(\"gdi32.dll\")]\n    private static extern bool BitBlt(",
        1,
    )

io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("screen backdrop split:", "CaptureScreen" in s, "Cropplate" in s, "ComposeFrom" in s)
