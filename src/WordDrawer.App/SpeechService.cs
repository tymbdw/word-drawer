using System.Diagnostics;
using System.IO;
using System.Media;

namespace WordDrawer.App;

/// <summary>
/// Offline pronunciation. Ships Piper next to the executable, so the sound is identical on
/// every machine and does not depend on whatever voices Windows happens to have installed.
/// </summary>
internal sealed class SpeechService : IDisposable
{
    private readonly string _piperDirectory;
    private readonly string _piperExe;
    private readonly string _modelPath;
    private readonly SoundPlayer _player = new();
    private readonly string _wavPath;
    private bool _disposed;

    public SpeechService()
    {
        // espeak-ng cannot open its data files from a non-ASCII path, so the installer puts
        // the engine under %LOCALAPPDATA% (always ASCII) and we prefer it over the app folder.
        var shared = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "WordDrawer", "piper");
        var beside = Path.Combine(AppContext.BaseDirectory, "piper");
        _piperDirectory = File.Exists(Path.Combine(shared, "piper.exe")) ? shared : beside;
        _piperExe = Path.Combine(_piperDirectory, "piper.exe");
        _modelPath = Path.Combine(_piperDirectory, "en_US-lessac-medium.onnx");
        _wavPath = Path.Combine(Path.GetTempPath(), "worddrawer-speak.wav");
    }

    public bool Available => File.Exists(_piperExe) && File.Exists(_modelPath);

    /// <summary>Synthesises one word and plays it. Returns false when it could not be played.</summary>
    public bool Speak(string? word)
    {
        if (_disposed || !Available || string.IsNullOrWhiteSpace(word))
        {
            return false;
        }

        try
        {
            if (File.Exists(_wavPath))
            {
                File.Delete(_wavPath);
            }

            var start = new ProcessStartInfo(_piperExe)
            {
                WorkingDirectory = _piperDirectory,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            start.ArgumentList.Add("--model");
            start.ArgumentList.Add(_modelPath);
            start.ArgumentList.Add("--output_file");
            start.ArgumentList.Add(_wavPath);

            using var piper = Process.Start(start);
            if (piper is null)
            {
                return false;
            }

            piper.StandardInput.WriteLine(word);
            piper.StandardInput.Close();
            piper.StandardError.ReadToEnd();
            piper.WaitForExit(4000);

            if (!File.Exists(_wavPath))
            {
                return false;
            }

            _player.SoundLocation = _wavPath;
            _player.Play();
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        try
        {
            _player.Stop();
            _player.Dispose();
        }
        catch (Exception)
        {
            // exiting anyway
        }
    }
}
