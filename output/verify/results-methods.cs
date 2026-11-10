    private async Task ShowWordBookAsync()
    {
        try
        {
            var total = await _database.CountWordsInActiveBookAsync();
            var remaining = await _database.CountUnstudiedWordsAsync();
            var learned = Math.Max(0, total - remaining);
            var percent = total == 0 ? 0 : learned * 100.0 / total;

            BookNameText.Text = KaoyanWordBook.Name;
            BookSourceText.Text = KaoyanWordBook.Source;
            BookTotalText.Text = total.ToString("N0", CultureInfo.InvariantCulture);
            BookLearnedText.Text = learned.ToString("N0", CultureInfo.InvariantCulture);
            BookProgressBar.Value = percent;
            BookProgressText.Text = $"{percent:0.0}% · 剩余 {remaining:N0} 词";

            ShowView(WordBookView);
        }
        catch (Exception exception)
        {
            StatusText.Text = $"读取词书失败：{exception.Message}";
        }
    }

    private async Task ShowResultsAsync()
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var dashboard = await _database.GetDashboardAsync(today);
            ResultTotalText.Text = dashboard.UniqueWordsStudied.ToString("N0", CultureInfo.InvariantCulture);
            ResultTodayText.Text = dashboard.TodayUniqueWordsStudied.ToString("N0", CultureInfo.InvariantCulture);

            var stats = await _database.GetRecentDailyStatsAsync(today, 7);
            var byDate = stats.ToDictionary(stat => stat.Date);
            var bars = new[] { Bar0, Bar1, Bar2, Bar3, Bar4, Bar5, Bar6 };
            var labels = new[] { BarDay0, BarDay1, BarDay2, BarDay3, BarDay4, BarDay5, BarDay6 };

            var counts = new int[7];
            for (var i = 0; i < 7; i++)
            {
                var date = today.AddDays(i - 6);
                counts[i] = byDate.TryGetValue(date, out var stat) ? stat.UniqueWordsStudied : 0;
                labels[i].Text = date.ToString("M/d", CultureInfo.InvariantCulture);
            }

            var peak = Math.Max(1, counts.Max());
            for (var i = 0; i < 7; i++)
            {
                bars[i].Height = Math.Max(2, counts[i] / (double)peak * 68);
            }

            ShowView(ResultsView);
        }
        catch (Exception exception)
        {
            StatusText.Text = $"读取学习成果失败：{exception.Message}";
        }
    }

    private async Task StartStudySessionAsync()