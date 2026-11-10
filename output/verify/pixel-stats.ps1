param(
    [string]$Path = "D:\Window Word\output\wpf\v2-home.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class PixelStats {
    public static void Run(string path) {
        using (var bmp = new Bitmap(path)) {
            var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int bytes = Math.Abs(data.Stride) * bmp.Height;
            byte[] buf = new byte[bytes];
            Marshal.Copy(data.Scan0, buf, 0, bytes);
            bmp.UnlockBits(data);

            long alphaSum = 0; int minA = 255, maxA = 0; long n = 0;
            long[] hist = new long[8];
            for (int y = 0; y < bmp.Height; y++) {
                int row = y * data.Stride;
                for (int x = 0; x < bmp.Width; x++) {
                    byte a = buf[row + x * 4 + 3];
                    alphaSum += a; n++;
                    if (a < minA) minA = a;
                    if (a > maxA) maxA = a;
                    hist[a / 32]++;
                }
            }
            Console.WriteLine("alpha min=" + minA + " max=" + maxA + " avg=" + (alphaSum / (double)n).ToString("F1"));
            for (int i = 0; i < 8; i++) Console.WriteLine("  alpha bucket " + (i*32) + "-" + (i*32+31) + ": " + hist[i]);

            int[] xs = { 20, 270, 520, 270, 270, 270, 100, 470 };
            int[] ys = { 100, 100, 100, 300, 450, 500, 700, 200 };
            for (int i = 0; i < xs.Length; i++) {
                int idx = ys[i] * data.Stride + xs[i] * 4;
                byte b = buf[idx], g = buf[idx+1], r = buf[idx+2], a2 = buf[idx+3];
                Console.WriteLine(string.Format("px({0},{1}) rgba=({2},{3},{4},{5})", xs[i], ys[i], r, g, b, a2));
            }
        }
    }
}
"@

[PixelStats]::Run($Path)
