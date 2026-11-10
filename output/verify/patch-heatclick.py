import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

# 1. a detail line that the clicked cell fills in
s = io.open(xaml, encoding="utf-8-sig").read()
old = '''                                <TextBlock Text="最近 90 天" FontSize="10"
                                           Foreground="{DynamicResource TextSecondary}" />'''
new = '''                                <Grid>
                                    <TextBlock Text="最近 90 天" FontSize="10"
                                               Foreground="{DynamicResource TextSecondary}" />
                                    <TextBlock x:Name="HeatDetailText" Text="" HorizontalAlignment="Right"
                                               FontSize="10" Foreground="{DynamicResource TextSecondary}" />
                                </Grid>'''
assert s.count(old) == 1
s = s.replace(old, new)
io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("detail line added")

# 2. clicking a cell pins its numbers
c = io.open(cs, encoding="utf-8-sig").read()

c = c.replace(
    "    private bool _dragging;",
    """    private bool _dragging;
    private Border? _selectedHeatCell;
    private IReadOnlyDictionary<DateOnly, DailyStat> _heatStats = new Dictionary<DateOnly, DailyStat>();""",
    1,
)

old2 = '''            if (inWindow)
            {
                cell.ToolTip = $"{date.Month} 月 {date.Day} 日 · {count} 词";
            }
            else
            {
                cell.Opacity = 0.25;
            }'''
new2 = '''            if (inWindow)
            {
                cell.Tag = date;
                cell.Cursor = Cursors.Hand;
                cell.ToolTip = BuildHeatTooltip(date, count);
                cell.MouseLeftButtonUp += HeatCell_Click;
            }
            else
            {
                cell.Opacity = 0.25;
            }'''
assert c.count(old2) == 1
c = c.replace(old2, new2)

# remember the stats + default selection after the grid is built
old3 = '''        // month labels above the first column of each new month'''
new3 = '''        _heatStats = byDate;
        _selectedHeatCell = null;
        HeatDetailText.Text = string.Empty;

        // month labels above the first column of each new month'''
assert c.count(old3) == 1
c = c.replace(old3, new3)

# helpers
old4 = '''    private System.Windows.Media.Brush LevelBrush(int count, int peak)'''
new4 = '''    private ToolTip BuildHeatTooltip(DateOnly date, int count)
    {
        var seconds = _heatStats.TryGetValue(date, out var stat) ? stat.EffectiveSeconds : 0;
        return new ToolTip
        {
            Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(0xF2, 0x1B, 0x28, 0x36)),
            BorderThickness = new Thickness(0),
            Padding = new Thickness(9, 6, 9, 6),
            HasDropShadow = true,
            Content = new TextBlock
            {
                Text = $"{date:yyyy-MM-dd}\\n背了 {count} 词 · 有效 {FormatDuration(seconds)}",
                FontSize = 10,
                LineHeight = 16,
                Foreground = System.Windows.Media.Brushes.White
            }
        };
    }

    private void HeatCell_Click(object sender, MouseButtonEventArgs e)
    {
        if (sender is Border { Tag: DateOnly date } cell)
        {
            SelectHeatCell(cell, date);
        }
    }

    private void SelectHeatCell(Border cell, DateOnly date)
    {
        if (_selectedHeatCell is not null)
        {
            _selectedHeatCell.BorderThickness = new Thickness(0);
        }

        _selectedHeatCell = cell;
        cell.BorderThickness = new Thickness(1.4);
        cell.BorderBrush = (System.Windows.Media.Brush)Resources["TextPrimary"];

        var count = _heatStats.TryGetValue(date, out var stat) ? stat.UniqueWordsStudied : 0;
        var seconds = _heatStats.TryGetValue(date, out var same) ? same.EffectiveSeconds : 0;
        HeatDetailText.Text = $"{date.Month} 月 {date.Day} 日 · {count} 词 · {FormatDuration(seconds)}";
    }

    private System.Windows.Media.Brush LevelBrush(int count, int peak)'''
assert c.count(old4) == 1
c = c.replace(old4, new4)

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("click handling added")
