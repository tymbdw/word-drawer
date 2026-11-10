import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

# ---------- XAML ----------
s = io.open(xaml, encoding="utf-8-sig").read()

block_start = s.index('                        <Border CornerRadius="16" Background="{DynamicResource PanelFill}"\n                                BorderBrush="{DynamicResource PanelStroke}" BorderThickness="1"\n                                Padding="14,11" Margin="0,0,0,8">\n                            <StackPanel>\n                                <TextBlock Text="快捷键"')
speak_tag = s.index('Tag="Speak" Click="ShortcutButton_Click"')
block_end = s.index('                        </Border>\n', speak_tag) + len('                        </Border>\n')
s = s[:block_start] + s[block_end:]
s = s.replace(' PreviewKeyDown="Window_PreviewKeyDown"', '')
io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("xaml: block gone =", "快捷键" not in s, "| preview gone =", "Window_PreviewKeyDown" not in s)

# ---------- code ----------
c = io.open(cs, encoding="utf-8-sig").read()

c = c.replace("""    private readonly Dictionary<string, Shortcut> _shortcuts = new(StringComparer.Ordinal)
    {
        ["Known"] = new Shortcut(Key.Right, ModifierKeys.None),
        ["Unknown"] = new Shortcut(Key.A, ModifierKeys.None),
        ["Meaning"] = new Shortcut(Key.H, ModifierKeys.None),
        ["Speak"] = new Shortcut(Key.Space, ModifierKeys.None)
    };
""", "")
c = c.replace("    private string? _capturing;\n", "")
c = c.replace("""
        foreach (var action in _shortcuts.Keys.ToList())
        {
            var stored = await _database.GetSettingAsync($"Key.{action}");
            if (Shortcut.TryParse(stored, out var parsed))
            {
                _shortcuts[action] = parsed;
            }
        }

        UpdateShortcutLabels();""", "")

start = c.index("    private void UpdateShortcutLabels()")
end = c.index("    private void PreviousWord()")
replacement = """    private async void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (StudyView.Visibility != Visibility.Visible)
        {
            return;
        }

        if (e.Key == Key.Left)
        {
            PreviousWord();
            e.Handled = true;
        }
        else if (e.Key == Key.Right)
        {
            await RecordAndMoveAsync(known: true);
            e.Handled = true;
        }
    }

"""
c = c[:start] + replacement + c[end:]

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("code: _shortcuts =", c.count("_shortcuts"), "| capturing =", c.count("_capturing"), "| Shortcut type =", c.count("record struct Shortcut"))
