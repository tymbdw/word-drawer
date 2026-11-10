import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

s = io.open(xaml, encoding="utf-8-sig").read()

results_at = s.index('<Grid x:Name="ResultsView"')
panel_start = s.index('<StackPanel Grid.Row="1">', results_at)
panel_end = s.index("                    </StackPanel>\n                </Grid>", panel_start) + len("                    </StackPanel>")

new_panel = '''<ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Disabled">
                    <StackPanel>
                        <Border CornerRadius="18" Background="{DynamicResource PanelFill}"
                                BorderBrush="{DynamicResource PanelStroke}" BorderThickness="1" Padding="16,14">
                            <StackPanel>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition />
                                        <ColumnDefinition Width="1" />
                                        <ColumnDefinition />
                                    </Grid.ColumnDefinitions>
                                    <StackPanel>
                                        <TextBlock x:Name="ResultActiveDaysText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="30" Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="学习天数" Margin="0,4,0,0" FontSize="10"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                    <Border Grid.Column="1" Height="38" VerticalAlignment="Center"
                                            Background="{DynamicResource Divider}" />
                                    <StackPanel Grid.Column="2" Margin="14,0,0,0">
                                        <TextBlock x:Name="ResultStreakText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="30" Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="连续天数" Margin="0,4,0,0" FontSize="10"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                </Grid>

                                <TextBlock x:Name="ResultSummaryText" Text="—" Margin="0,10,0,0" FontSize="9"
                                           TextWrapping="Wrap" Foreground="{DynamicResource TextSecondary}" />

                                <Border Height="1" Background="{DynamicResource Divider}" Margin="0,14,0,12" />

                                <TextBlock Text="最近 90 天" FontSize="10"
                                           Foreground="{DynamicResource TextSecondary}" />

                                <Grid x:Name="HeatMonthRow" Height="14" Margin="28,8,0,0" />

                                <Grid Margin="0,1,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="28" />
                                        <ColumnDefinition />
                                    </Grid.ColumnDefinitions>
                                    <Grid Grid.Column="0" Height="112">
                                        <Grid.RowDefinitions>
                                            <RowDefinition />
                                            <RowDefinition />
                                            <RowDefinition />
                                            <RowDefinition />
                                            <RowDefinition />
                                            <RowDefinition />
                                            <RowDefinition />
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Text="周一" FontSize="8" VerticalAlignment="Center"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                        <TextBlock Grid.Row="2" Text="周三" FontSize="8" VerticalAlignment="Center"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                        <TextBlock Grid.Row="4" Text="周五" FontSize="8" VerticalAlignment="Center"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </Grid>
                                    <Grid x:Name="HeatmapGrid" Grid.Column="1" Height="112" Margin="0,0,0,0" />
                                </Grid>

                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                                    <TextBlock Text="少" FontSize="8.5" VerticalAlignment="Center"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <Border x:Name="Legend0" Width="10" Height="10" CornerRadius="2" Margin="6,0,0,0"
                                            Background="{DynamicResource Divider}" />
                                    <Border x:Name="Legend1" Width="10" Height="10" CornerRadius="2" Margin="3,0,0,0"
                                            Background="#4D2899D6" />
                                    <Border x:Name="Legend2" Width="10" Height="10" CornerRadius="2" Margin="3,0,0,0"
                                            Background="#992899D6" />
                                    <Border x:Name="Legend3" Width="10" Height="10" CornerRadius="2" Margin="3,0,0,0"
                                            Background="#FF2899D6" />
                                    <TextBlock Text="多" FontSize="8.5" VerticalAlignment="Center" Margin="6,0,0,0"
                                               Foreground="{DynamicResource TextSecondary}" />
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>'''

s = s[:panel_start] + new_panel + s[panel_end:]
io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("results layout replaced")

# ---------------- code behind ----------------
c = io.open(cs, encoding="utf-8-sig").read()

sig = "    private async Task ShowResultsAsync()"
start = c.index(sig)
i = c.index("{", start)
depth = 0
end = i
while True:
    if c[end] == "{":
        depth += 1
    elif c[end] == "}":
        depth -= 1
        if depth == 0:
            end += 1
            break
    end += 1

new_method = '''    private async Task ShowResultsAsync()
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var dashboard = await _database.GetDashboardAsync(today);
            var stats = await _database.GetRecentDailyStatsAsync(today, 90);
            var byDate = stats.ToDictionary(stat => stat.Date);

            var activeDays = stats.Count(stat => stat.UniqueWordsStudied > 0);
            var streak = 0;
            for (var day = today; ; day = day.AddDays(-1))
            {
                if (!byDate.TryGetValue(day, out var entry) || entry.UniqueWordsStudied <= 0)
                {
                    break;
                }

                streak++;
            }

            ResultActiveDaysText.Text = activeDays.ToString(CultureInfo.InvariantCulture);
            ResultStreakText.Text = streak.ToString(CultureInfo.InvariantCulture);

            var todaySeconds = byDate.TryGetValue(today, out var todayStat) ? todayStat.EffectiveSeconds : 0;
            ResultSummaryText.Text =
                $"累计学习 {dashboard.UniqueWordsStudied:N0} 词 · 今日 {dashboard.TodayUniqueWordsStudied} 词 · " +
                $"有效 {FormatDuration(todaySeconds)}";

            BuildHeatmap(today, byDate);

            ShowView(ResultsView);
        }
        catch (Exception exception)
        {
            StatusText.Text = $"读取学习成果失败：{exception.Message}";
        }
    }

    /// <summary>
    /// GitHub-style contribution calendar: one column per week, Monday on top, 90 days back.
    /// </summary>
    private void BuildHeatmap(DateOnly today, IReadOnlyDictionary<DateOnly, DailyStat> byDate)
    {
        const int window = 90;
        var first = today.AddDays(-(window - 1));
        var startOffset = ((int)first.DayOfWeek + 6) % 7;   // Monday = 0
        var gridStart = first.AddDays(-startOffset);
        var weeks = (startOffset + window + 6) / 7;

        HeatmapGrid.Children.Clear();
        HeatmapGrid.ColumnDefinitions.Clear();
        HeatmapGrid.RowDefinitions.Clear();
        HeatMonthRow.Children.Clear();
        HeatMonthRow.ColumnDefinitions.Clear();

        for (var column = 0; column < weeks; column++)
        {
            HeatmapGrid.ColumnDefinitions.Add(new ColumnDefinition());
            HeatMonthRow.ColumnDefinitions.Add(new ColumnDefinition());
        }

        for (var row = 0; row < 7; row++)
        {
            HeatmapGrid.RowDefinitions.Add(new RowDefinition());
        }

        var peak = Math.Max(1, byDate.Values.Where(stat => stat.Date >= first).Select(stat => stat.UniqueWordsStudied).DefaultIfEmpty(0).Max());
        var months = CultureInfo.GetCultureInfo("zh-CN").DateTimeFormat;

        for (var index = 0; index < weeks * 7; index++)
        {
            var date = gridStart.AddDays(index);
            var inWindow = date >= first && date <= today;
            var count = inWindow && byDate.TryGetValue(date, out var stat) ? stat.UniqueWordsStudied : 0;

            var cell = new Border
            {
                CornerRadius = new CornerRadius(2),
                Margin = new Thickness(1.5),
                Background = count <= 0 ? (System.Windows.Media.Brush)Resources["Divider"] : LevelBrush(count, peak)
            };

            if (inWindow)
            {
                cell.ToolTip = $"{date.Month} 月 {date.Day} 日 · {count} 词";
            }
            else
            {
                cell.Opacity = 0.25;
            }

            Grid.SetColumn(cell, index / 7);
            Grid.SetRow(cell, index % 7);
            HeatmapGrid.Children.Add(cell);
        }

        // month labels above the first column of each new month
        var lastMonth = -1;
        for (var index = 0; index < weeks * 7; index++)
        {
            var date = gridStart.AddDays(index);
            if (date > today || date < first || date.Month == lastMonth || date.Day > 7)
            {
                continue;
            }

            lastMonth = date.Month;
            var label = new TextBlock
            {
                Text = $"{date.Month}月",
                FontSize = 8,
                Foreground = (System.Windows.Media.Brush)Resources["TextSecondary"]
            };
            Grid.SetColumn(label, index / 7);
            HeatMonthRow.Children.Add(label);
        }
    }

    private System.Windows.Media.Brush LevelBrush(int count, int peak)
    {
        var ratio = count / (double)peak;
        var alpha = ratio <= 0.34 ? (byte)0x55 : ratio <= 0.67 ? (byte)0x99 : (byte)0xFF;
        var brush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(alpha, 0x28, 0x99, 0xD6));
        brush.Freeze();
        return brush;
    }'''

c = c[:start] + new_method + c[end:]
io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("ShowResultsAsync rebuilt")
