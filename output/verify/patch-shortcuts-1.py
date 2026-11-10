import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

# ---------------- XAML: four rebindable rows in settings ----------------
s = io.open(xaml, encoding="utf-8-sig").read()

anchor = '''                            <TextBlock x:Name="VersionText" Text="v0.0.0" HorizontalAlignment="Right"'''
row = '''                        <Border CornerRadius="16" Background="{DynamicResource PanelFill}"
                                BorderBrush="{DynamicResource PanelStroke}" BorderThickness="1"
                                Padding="14,11" Margin="0,0,0,8">
                            <StackPanel>
                                <TextBlock Text="快捷键" Style="{StaticResource SettingTitle}" />
                                <TextBlock Text="点右侧按钮后按下新按键，Esc 取消" Style="{StaticResource SettingHint}" />
                                <Grid Margin="0,10,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition />
                                        <ColumnDefinition />
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="30" />
                                        <RowDefinition Height="30" />
                                        <RowDefinition Height="30" />
                                        <RowDefinition Height="30" />
                                    </Grid.RowDefinitions>

                                    <TextBlock Grid.Row="0" Text="认识" VerticalAlignment="Center" FontSize="10"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <Button x:Name="KeyKnownButton" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Right"
                                            Height="24" Padding="10,0" FontSize="10" Style="{StaticResource SegmentButton}"
                                            Tag="Known" Click="ShortcutButton_Click" />

                                    <TextBlock Grid.Row="1" Text="不认识" VerticalAlignment="Center" FontSize="10"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <Button x:Name="KeyUnknownButton" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Right"
                                            Height="24" Padding="10,0" FontSize="10" Style="{StaticResource SegmentButton}"
                                            Tag="Unknown" Click="ShortcutButton_Click" />

                                    <TextBlock Grid.Row="2" Text="释义开关" VerticalAlignment="Center" FontSize="10"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <Button x:Name="KeyMeaningButton" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Right"
                                            Height="24" Padding="10,0" FontSize="10" Style="{StaticResource SegmentButton}"
                                            Tag="Meaning" Click="ShortcutButton_Click" />

                                    <TextBlock Grid.Row="3" Text="朗读单词" VerticalAlignment="Center" FontSize="10"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <Button x:Name="KeySpeakButton" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Right"
                                            Height="24" Padding="10,0" FontSize="10" Style="{StaticResource SegmentButton}"
                                            Tag="Speak" Click="ShortcutButton_Click" />
                                </Grid>
                            </StackPanel>
                        </Border>

'''
assert s.count(anchor) == 1
s = s.replace(anchor, row + anchor)
io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("settings rows added")

# ---------------- code ----------------
c = io.open(cs, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global c
    assert c.count(old) == n, (c.count(old), old[:60])
    c = c.replace(old, new)


rep(
    "    private bool _showMeaning;",
    """    private bool _showMeaning;
    private readonly Dictionary<string, KeyGesture> _shortcuts = new(StringComparer.Ordinal)
    {
        ["Known"] = new KeyGesture(Key.Right),
        ["Unknown"] = new KeyGesture(Key.A),
        ["Meaning"] = new KeyGesture(Key.H),
        ["Speak"] = new KeyGesture(Key.Space)
    };
    private string? _capturing;""",
)

# load persisted shortcuts
rep(
    """        _showMeaning = string.Equals(await _database.GetSettingAsync("ShowMeaning"), "1", StringComparison.Ordinal);""",
    """        _showMeaning = string.Equals(await _database.GetSettingAsync("ShowMeaning"), "1", StringComparison.Ordinal);

        foreach (var action in _shortcuts.Keys.ToList())
        {
            var stored = await _database.GetSettingAsync($"Key.{action}");
            if (!string.IsNullOrWhiteSpace(stored) &&
                new KeyGestureConverter().ConvertFromInvariantString(stored) is KeyGesture gesture)
            {
                _shortcuts[action] = gesture;
            }
        }

        UpdateShortcutLabels();""",
)

# key handling
old_key = '''    private async void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)'''
new_key = '''    private void UpdateShortcutLabels()
    {
        KeyKnownButton.Content = DescribeGesture("Known");
        KeyUnknownButton.Content = DescribeGesture("Unknown");
        KeyMeaningButton.Content = DescribeGesture("Meaning");
        KeySpeakButton.Content = DescribeGesture("Speak");
    }

    private string DescribeGesture(string action) =>
        _capturing == action
            ? "按键…"
            : new KeyGestureConverter().ConvertToInvariantString(_shortcuts[action]);

    private void ShortcutButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string action })
        {
            return;
        }

        _capturing = action;
        UpdateShortcutLabels();
        StatusText.Text = "请按下新的按键，Esc 取消";
        Focus();
    }

    /// <summary>Returns true when the key was consumed while rebinding a shortcut.</summary>
    private bool TryCaptureShortcut(Key key)
    {
        if (_capturing is not { } action)
        {
            return false;
        }

        if (key == Key.Escape)
        {
            _capturing = null;
            UpdateShortcutLabels();
            StatusText.Text = "已取消";
            return true;
        }

        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftShift or Key.RightShift
            or Key.LeftAlt or Key.RightAlt or Key.System)
        {
            return true;
        }

        var modifiers = Keyboard.Modifiers;
        var gesture = modifiers == ModifierKeys.None ? new KeyGesture(key) : new KeyGesture(key, modifiers);
        _shortcuts[action] = gesture;
        _capturing = null;
        _ = _database.SetSettingAsync($"Key.{action}", new KeyGestureConverter().ConvertToInvariantString(gesture));
        UpdateShortcutLabels();
        StatusText.Text = "快捷键已更新";
        return true;
    }

    private bool MatchesShortcut(string action, Key key)
    {
        var gesture = _shortcuts[action];
        return gesture.Key == key && gesture.Modifiers == Keyboard.Modifiers;
    }

    private async void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)'''

c = c.replace(old_key, new_key, 1)

# inside the study-view key branch, route to actions
old_body = c[c.index("    private async void Window_KeyDown"):]
end = old_body.index("\n    private ")
old_body = old_body[:end]
print("OLD KEY BODY:\n", old_body)
