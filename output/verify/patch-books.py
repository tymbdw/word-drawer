import io

cs_path = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
xaml_path = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"

# ---------- code behind ----------
c = io.open(cs_path, encoding="utf-8-sig").read()


def repc(old, new, n=1):
    global c
    assert c.count(old) == n, (c.count(old), old[:70])
    c = c.replace(old, new)


# 1. seed every bundled book, not just the kaoyan one
repc(
    """            if (await _database.CountWordsInActiveBookAsync() < 100)
            {
                StatusText.Text = "正在写入内置词书…";
                await _database.SeedWordBookAsync(KaoyanWordBook.Name, KaoyanWordBook.Source, KaoyanWordBook.Load());
            }""",
    """            foreach (var book in BuiltInWordBooks.All)
            {
                if (await _database.WordBookExistsAsync(book.Name))
                {
                    continue;
                }

                StatusText.Text = $"正在写入{book.Name}…";
                await _database.SeedWordBookAsync(book.Name, book.Source, BuiltInWordBooks.Load(book));
            }

            // Never end up with no active book.
            var seeded = await _database.GetWordBookSummariesAsync();
            if (seeded.Count > 0 && seeded.All(book => !book.IsActive))
            {
                await _database.SetActiveWordBookAsync(seeded[^1].Id);
            }""",
)

# 2. the wordbook page becomes a list of every bundled book
old_show = c[c.index("    private async Task ShowWordBookAsync()"):]
end = old_show.index("\n    private async Task ShowResultsAsync()")
old_show = old_show[:end]

new_show = '''    private async Task ShowWordBookAsync()
    {
        try
        {
            var books = await _database.GetWordBookSummariesAsync();
            BookListPanel.Children.Clear();

            foreach (var book in books)
            {
                BookListPanel.Children.Add(BuildBookRow(book));
            }

            ShowView(WordBookView);
        }
        catch (Exception exception)
        {
            StatusText.Text = $"读取词书失败：{exception.Message}";
        }
    }

    private System.Windows.Controls.Border BuildBookRow(WordBookSummary book)
    {
        var percent = book.WordCount == 0 ? 0 : book.LearnedCount * 100.0 / book.WordCount;

        var texts = new System.Windows.Controls.StackPanel();
        texts.Children.Add(new System.Windows.Controls.TextBlock
        {
            Text = book.Name,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = (System.Windows.Media.Brush)Resources["TextPrimary"],
            TextWrapping = TextWrapping.Wrap
        });
        texts.Children.Add(new System.Windows.Controls.TextBlock
        {
            Text = $"{book.WordCount:N0} 词 · 已学 {book.LearnedCount:N0} · {percent:0.0}%",
            FontSize = 9.5,
            Margin = new Thickness(0, 5, 0, 0),
            Foreground = (System.Windows.Media.Brush)Resources["TextSecondary"]
        });
        texts.Children.Add(new System.Windows.Controls.TextBlock
        {
            Text = book.Source,
            FontSize = 8,
            Margin = new Thickness(0, 4, 0, 0),
            Foreground = (System.Windows.Media.Brush)Resources["TextSecondary"],
            TextWrapping = TextWrapping.Wrap,
            Opacity = 0.8
        });

        var action = new System.Windows.Controls.Button
        {
            Content = book.IsActive ? "使用中" : "切换",
            Width = 54,
            Height = 26,
            FontSize = 10,
            IsEnabled = !book.IsActive,
            VerticalAlignment = VerticalAlignment.Center,
            Style = (Style)Resources["SegmentButton"]
        };
        if (!book.IsActive)
        {
            action.Tag = book.Id;
            action.Click += SwitchBook_Click;
        }

        var row = new System.Windows.Controls.Grid();
        row.ColumnDefinitions.Add(new System.Windows.Controls.ColumnDefinition());
        row.ColumnDefinitions.Add(new System.Windows.Controls.ColumnDefinition { Width = new GridLength(62) });
        System.Windows.Controls.Grid.SetColumn(texts, 0);
        System.Windows.Controls.Grid.SetColumn(action, 1);
        row.Children.Add(texts);
        row.Children.Add(action);

        return new System.Windows.Controls.Border
        {
            CornerRadius = new CornerRadius(16),
            Background = (System.Windows.Media.Brush)Resources["PanelFill"],
            BorderBrush = (System.Windows.Media.Brush)Resources["PanelStroke"],
            BorderThickness = new Thickness(1),
            Padding = new Thickness(14, 12, 12, 12),
            Margin = new Thickness(0, 0, 0, 9),
            Child = row
        };
    }

    private async void SwitchBook_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button { Tag: int id })
        {
            return;
        }

        try
        {
            await _database.SetActiveWordBookAsync(id);
            _newRemaining = await _database.CountUnstudiedWordsAsync();
            var dashboard = await _database.GetDashboardAsync(DateOnly.FromDateTime(DateTime.Today));
            _reviewRemaining = dashboard.DueReviewCount;
            _todayStudied = dashboard.TodayUniqueWordsStudied;
            _totalStudied = dashboard.UniqueWordsStudied;
            RefreshDashboard();
            StatusText.Text = "词书已切换";
            await ShowWordBookAsync();
        }
        catch (Exception exception)
        {
            StatusText.Text = $"切换失败：{exception.Message}";
        }
    }
'''

c = c.replace(old_show, new_show)
io.open(cs_path, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("code patched")

# ---------- xaml ----------
s = io.open(xaml_path, encoding="utf-8-sig").read()

start = s.index('                    <StackPanel Grid.Row="1">\n                        <Border CornerRadius="18" Background="{DynamicResource PanelFill}"')
end = s.index('                <Grid x:Name="ResultsView"')
block = s[start:end]
close = block.rindex("                </Grid>")
new_block = '''                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="BookListPanel" Margin="0,2,0,8" />
                    </ScrollViewer>
'''
s = s[:start] + new_block + s[end:]
io.open(xaml_path, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("xaml patched, list panel present:", 'x:Name="BookListPanel"' in s)
