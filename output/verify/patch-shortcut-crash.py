import io

cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
c = io.open(cs, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global c
    assert c.count(old) == n, (c.count(old), old[:70])
    c = c.replace(old, new)


# 1. plain record instead of KeyGesture (which rejects bare letters)
rep(
    """    private readonly Dictionary<string, KeyGesture> _shortcuts = new(StringComparer.Ordinal)
    {
        ["Known"] = new KeyGesture(Key.Right),
        ["Unknown"] = new KeyGesture(Key.A),
        ["Meaning"] = new KeyGesture(Key.H),
        ["Speak"] = new KeyGesture(Key.Space)
    };""",
    """    private readonly Dictionary<string, Shortcut> _shortcuts = new(StringComparer.Ordinal)
    {
        ["Known"] = new Shortcut(Key.Right, ModifierKeys.None),
        ["Unknown"] = new Shortcut(Key.A, ModifierKeys.None),
        ["Meaning"] = new Shortcut(Key.H, ModifierKeys.None),
        ["Speak"] = new Shortcut(Key.Space, ModifierKeys.None)
    };""",
)

# 2. parsing / formatting without KeyGestureConverter
rep(
    """            var stored = await _database.GetSettingAsync($"Key.{action}");
            if (!string.IsNullOrWhiteSpace(stored) &&
                new KeyGestureConverter().ConvertFromInvariantString(stored) is KeyGesture gesture)
            {
                _shortcuts[action] = gesture;
            }""",
    """            var stored = await _database.GetSettingAsync($"Key.{action}");
            if (Shortcut.TryParse(stored, out var parsed))
            {
                _shortcuts[action] = parsed;
            }""",
)

rep(
    """    private string DescribeGesture(string action) =>
        _capturing == action
            ? "按键…"
            : new KeyGestureConverter().ConvertToInvariantString(_shortcuts[action]);""",
    """    private string DescribeGesture(string action) =>
        _capturing == action ? "按键…" : _shortcuts[action].ToString();""",
)

rep(
    """        var gesture = Keyboard.Modifiers == ModifierKeys.None
            ? new KeyGesture(key)
            : new KeyGesture(key, Keyboard.Modifiers);
        _shortcuts[action] = gesture;
        _capturing = null;
        _ = _database.SetSettingAsync($"Key.{action}", new KeyGestureConverter().ConvertToInvariantString(gesture));""",
    """        var gesture = new Shortcut(key, Keyboard.Modifiers);
        _shortcuts[action] = gesture;
        _capturing = null;
        _ = _database.SetSettingAsync($"Key.{action}", gesture.ToString());""",
)

rep(
    """    private bool MatchesShortcut(string action, Key key) =>
        _shortcuts[action].Key == key && _shortcuts[action].Modifiers == Keyboard.Modifiers;""",
    """    private bool MatchesShortcut(string action, Key key) =>
        _shortcuts[action].Key == key && _shortcuts[action].Modifiers == Keyboard.Modifiers;

    /// <summary>A key plus its modifiers. Kept separate from KeyGesture, which refuses bare letters.</summary>
    private readonly record struct Shortcut(Key Key, ModifierKeys Modifiers)
    {
        public override string ToString()
        {
            var parts = new List<string>();
            if (Modifiers.HasFlag(ModifierKeys.Control))
            {
                parts.Add("Ctrl");
            }

            if (Modifiers.HasFlag(ModifierKeys.Shift))
            {
                parts.Add("Shift");
            }

            if (Modifiers.HasFlag(ModifierKeys.Alt))
            {
                parts.Add("Alt");
            }

            parts.Add(Key.ToString());
            return string.Join("+", parts);
        }

        public static bool TryParse(string? text, out Shortcut shortcut)
        {
            shortcut = default;
            if (string.IsNullOrWhiteSpace(text))
            {
                return false;
            }

            var modifiers = ModifierKeys.None;
            var parts = text.Split('+', StringSplitOptions.RemoveEmptyEntries);
            for (var i = 0; i < parts.Length - 1; i++)
            {
                modifiers |= parts[i].Trim().ToLowerInvariant() switch
                {
                    "ctrl" or "control" => ModifierKeys.Control,
                    "shift" => ModifierKeys.Shift,
                    "alt" => ModifierKeys.Alt,
                    _ => ModifierKeys.None
                };
            }

            if (!Enum.TryParse<Key>(parts[^1].Trim(), ignoreCase: true, out var key))
            {
                return false;
            }

            shortcut = new Shortcut(key, modifiers);
            return true;
        }
    }""",
)

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("shortcut storage fixed")

# 3. keep the piper files OUT of the single-file bundle (they were bloating it to 267 MB)
p = r"D:\Window Word\src\WordDrawer.App\WordDrawer.App.csproj"
s = io.open(p, encoding="utf-8-sig").read()
if "ExcludeFromSingleFile" not in s:
    s = s.replace(
        '<None Include="piper\\**\\*" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />',
        '<None Include="piper\\**\\*" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" ExcludeFromSingleFile="true" />')
    io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("piper excluded from bundle:", "ExcludeFromSingleFile" in io.open(p, encoding="utf-8-sig").read())
