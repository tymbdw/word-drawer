using System;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Drawing = System.Drawing;
using Drawing2D = System.Drawing.Drawing2D;
using DrawingImaging = System.Drawing.Imaging;
using Interop = System.Runtime.InteropServices;

namespace WordDrawer.App;

/// <summary>
/// Captures the desktop behind the drawer and composites the whole glass surface -
/// blurred backdrop, frost tint, diagonal sheen and the top-right highlight - into a
/// single bitmap. That bitmap becomes the Border's Background, so WPF clips it to the
/// rounded corners with antialiasing. A Border does not clip child elements, which is
/// why these layers cannot simply be stacked in XAML.
/// </summary>
internal static class ScreenBackdrop
{
    private const int SrcCopy = 0x00CC0020;

    [Interop.DllImport("user32.dll")]
    private static extern IntPtr GetDC(IntPtr hWnd);

    [Interop.DllImport("user32.dll")]
    private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDc);

    [Interop.DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    private const int SmCxScreen = 0;
    private const int SmCyScreen = 1;

    [Interop.DllImport("gdi32.dll")]
    private static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int width, int height, IntPtr hdcSrc, int xSrc, int ySrc, int rop);

    [Interop.DllImport("gdi32.dll")]
    private static extern bool DeleteObject(IntPtr hObject);

    /// <param name="physicalRect">Screen rectangle to sample, in physical pixels.</param>
    /// <param name="concealedRightPixels">Width of the strip our own collapsed window occupies at the right edge.</param>
    /// <param name="glassAlpha">Frost veil opacity, 0-255.</param>
    /// <param name="tintR">Frost veil red channel.</param>
    /// <param name="tintG">Frost veil green channel.</param>
    /// <param name="tintB">Frost veil blue channel.</param>
    public static ImageSource? Compose(Rect physicalRect, int concealedRightPixels, byte glassAlpha, byte tintR, byte tintG, byte tintB)
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

        // Blur by shrinking hard, smoothing, then stretching back up.
        var smallWidth = Math.Max(2, width / 10);
        var smallHeight = Math.Max(2, height / 10);
        using var small = new Drawing.Bitmap(smallWidth, smallHeight, DrawingImaging.PixelFormat.Format32bppArgb);
        using (var graphics = Drawing.Graphics.FromImage(small))
        {
            graphics.InterpolationMode = Drawing2D.InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = Drawing2D.PixelOffsetMode.HighQuality;
            graphics.DrawImage(captured, new Drawing.Rectangle(0, 0, smallWidth, smallHeight));
        }

        BoxBlur(small, 2);

        using var composed = new Drawing.Bitmap(width, height, DrawingImaging.PixelFormat.Format32bppArgb);
        using (var graphics = Drawing.Graphics.FromImage(composed))
        {
            graphics.InterpolationMode = Drawing2D.InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = Drawing2D.PixelOffsetMode.HighQuality;
            graphics.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias;
            graphics.DrawImage(small, new Drawing.Rectangle(0, 0, width, height));

            var full = new Drawing.Rectangle(0, 0, width, height);

            using (var tint = new Drawing.SolidBrush(Drawing.Color.FromArgb(glassAlpha, tintR, tintG, tintB)))
            {
                graphics.FillRectangle(tint, full);
            }

            using (var sheen = new Drawing2D.LinearGradientBrush(
                       full,
                       Drawing.Color.FromArgb(0x36, 255, 255, 255),
                       Drawing.Color.FromArgb(0x22, 255, 255, 255),
                       45f))
            {
                sheen.InterpolationColors = new Drawing2D.ColorBlend(3)
                {
                    Colors = new[]
                    {
                        Drawing.Color.FromArgb(0x36, 255, 255, 255),
                        Drawing.Color.FromArgb(0x12, 0x8E, 0xDC, 0xFA),
                        Drawing.Color.FromArgb(0x22, 255, 255, 255)
                    },
                    Positions = new[] { 0f, 0.56f, 1f }
                };
                graphics.FillRectangle(sheen, full);
            }

            // radial highlight anchored at 88% / 0%, matching the prototype's ::before
            var glowSize = (int)(width * 0.9);
            var glowRect = new Drawing.Rectangle(
                (int)(width * 0.88) - glowSize / 2,
                -glowSize / 2,
                glowSize,
                glowSize);
            using var glowPath = new Drawing2D.GraphicsPath();
            glowPath.AddEllipse(glowRect);
            using var glow = new Drawing2D.PathGradientBrush(glowPath);
            glow.CenterColor = Drawing.Color.FromArgb(0x33, 0x8E, 0xDC, 0xFF);
            glow.SurroundColors = new[] { Drawing.Color.FromArgb(0x00, 0x8E, 0xDC, 0xFF) };
            graphics.FillPath(glow, glowPath);

        }

        var handle = composed.GetHbitmap();
        try
        {
            var source = Imaging.CreateBitmapSourceFromHBitmap(
                handle,
                IntPtr.Zero,
                Int32Rect.Empty,
                BitmapSizeOptions.FromEmptyOptions());
            source.Freeze();
            return source;
        }
        finally
        {
            DeleteObject(handle);
        }
    }

    private static void BoxBlur(Drawing.Bitmap bitmap, int radius)
    {
        if (radius < 1)
        {
            return;
        }

        var width = bitmap.Width;
        var height = bitmap.Height;
        var rect = new Drawing.Rectangle(0, 0, width, height);
        var data = bitmap.LockBits(rect, DrawingImaging.ImageLockMode.ReadWrite, DrawingImaging.PixelFormat.Format32bppArgb);
        try
        {
            var stride = data.Stride;
            var bytes = Math.Abs(stride) * height;
            var buffer = new byte[bytes];
            Interop.Marshal.Copy(data.Scan0, buffer, 0, bytes);

            for (var pass = 0; pass < 2; pass++)
            {
                for (var y = 0; y < height; y++)
                {
                    for (var x = 0; x < width; x++)
                    {
                        int r = 0, g = 0, b = 0, count = 0;
                        for (var dy = -radius; dy <= radius; dy++)
                        {
                            var ny = Math.Clamp(y + dy, 0, height - 1);
                            for (var dx = -radius; dx <= radius; dx++)
                            {
                                var nx = Math.Clamp(x + dx, 0, width - 1);
                                var index = ny * stride + nx * 4;
                                b += buffer[index];
                                g += buffer[index + 1];
                                r += buffer[index + 2];
                                count++;
                            }
                        }

                        var target = y * stride + x * 4;
                        buffer[target] = (byte)(b / count);
                        buffer[target + 1] = (byte)(g / count);
                        buffer[target + 2] = (byte)(r / count);
                        buffer[target + 3] = 255;
                    }
                }
            }

            Interop.Marshal.Copy(buffer, 0, data.Scan0, bytes);
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

}

