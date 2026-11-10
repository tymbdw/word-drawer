import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

# ---------------- XAML ----------------
s = io.open(xaml, encoding="utf-8-sig").read()

# 1. not always on top any more
old = 'Background="Transparent" ShowInTaskbar="True" Topmost="True"'
new = 'Background="Transparent" ShowInTaskbar="True" Topmost="False"'
assert s.count(old) == 1
s = s.replace(old, new)

# 2. a close button that really exits
old2 = '''                            <Button Style="{StaticResource IconButton}" ToolTip="设置" Click="SettingsButton_Click">
                                <TextBlock Text="&#xE713;" FontFamily="Segoe Fluent Icons" FontSize="17"
                                           FontWeight="Normal" Foreground="{DynamicResource TextPrimary}" />
                            </Button>'''
new2 = old2 + '''
                            <Button Style="{StaticResource IconButton}" ToolTip="退出程序" Click="ExitButton_Click">
                                <TextBlock Text="&#x2715;" FontSize="13" FontWeight="Normal"
                                           Foreground="{DynamicResource TextPrimary}" />
                            </Button>'''
assert s.count(old2) == 1
s = s.replace(old2, new2)

# 3. a global meaning toggle on the study page
old3 = '''                        <StackPanel HorizontalAlignment="Center">
                            <TextBlock x:Name="SessionTitleText"'''
new3 = '''                        <Button x:Name="MeaningToggleButton" Content="释义" HorizontalAlignment="Right"
                                VerticalAlignment="Center" Height="26" Padding="10,0" FontSize="10"
                                Style="{StaticResource SegmentButton}" Click="ToggleMeaning_Click" />
                        <StackPanel HorizontalAlignment="Center">
                            <TextBlock x:Name="SessionTitleText"'''
assert s.count(old3) == 1
s = s.replace(old3, new3)

io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("xaml ready")

# ---------------- code ----------------
c = io.open(cs, encoding="utf-8-sig").read()


def rep(old_text, new_text, count=1):
    global c
    assert c.count(old_text) == count, (c.count(old_text), old_text[:60])
    c = c.replace(old_text, new_text)


# pin is what puts the drawer above other windows
rep(
    """        _isPinned = !_isPinned;
        PinButton.Opacity = _isPinned ? 1 : 0.72;""",
    """        _isPinned = !_isPinned;
        Topmost = _isPinned;
        PinButton.Opacity = _isPinned ? 1 : 0.72;""",
)

rep(
    """        _autoHide = !string.Equals(await _database.GetSettingAsync("AutoHide"), "0", StringComparison.Ordinal);""",
    """        _autoHide = !string.Equals(await _database.GetSettingAsync("AutoHide"), "0", StringComparison.Ordinal);
        _showMeaning = !string.Equals(await _database.GetSettingAsync("ShowMeaning"), "0", StringComparison.Ordinal);
        _isPinned = string.Equals(await _database.GetSettingAsync("Pinned"), "1", StringComparison.Ordinal);
        Topmost = _isPinned;""",
)

rep(
    "    private bool _isFloating;",
    "    private bool _isFloating;\n    private bool _showMeaning;",
)

# meaning visibility follows the toggle
rep(
    """        var word = _session[_wordIndex].Word;
        EnglishWordText.Text = word.English;
        MeaningText.Text = $"{word.PartOfSpeech} {word.Meaning}";""",
    """        var word = _session[_wordIndex].Word;
        EnglishWordText.Text = word.English;
        MeaningText.Text = $"{word.PartOfSpeech} {word.Meaning}";
        MeaningText.Visibility = _showMeaning ? Visibility.Visible : Visibility.Collapsed;
        MeaningToggleButton.Content = _showMeaning ? "释义 开" : "释义";""",
)

# handlers
rep(
    "    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();",
    """    private void ToggleMeaning_Click(object sender, RoutedEventArgs e)
    {
        _showMeaning = !_showMeaning;
        _ = _database.SetSettingAsync("ShowMeaning", _showMeaning ? "1" : "0");
        if (_session.Count > 0)
        {
            ShowCurrentWord(updateStatus: false);
        }
    }

    private void ExitButton_Click(object sender, RoutedEventArgs e) => ExitApplication();

    /// <summary>Real exit: the tray icon, the timers and the process all go away.</summary>
    private void ExitApplication()
    {
        _studyTimer.Stop();
        _edgeTimer.Stop();
        _hideTimer.Stop();
        FlushStudyTime();

        try
        {
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
        }
        catch (Exception)
        {
            // shutting down anyway
        }

        System.Windows.Application.Current.Shutdown();
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => ExitApplication();""",
)

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("code ready")
