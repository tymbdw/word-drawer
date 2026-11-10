import io

xaml = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

s = io.open(xaml, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global s
    assert s.count(old) == n, (s.count(old), old[:60])
    s = s.replace(old, new)


# 1. drop the 演示数据 badge
rep(
    """                        <Border HorizontalAlignment="Right" VerticalAlignment="Top"
                                Padding="8,5" CornerRadius="12" BorderBrush="{DynamicResource StrokeSoft}"
                                BorderThickness="1" Background="#10FFFFFF">
                            <TextBlock Text="演示数据" FontSize="9" Foreground="{DynamicResource TextSecondary}" />
                        </Border>
""",
    "",
)

# 2. 去复习: the user does not want the subtitle line
rep(
    """                                <TextBlock Text="去复习" HorizontalAlignment="Center" FontSize="13"
                                           FontWeight="SemiBold" />
                                <TextBlock Text="优先处理逾期词" Margin="0,3,0,0" HorizontalAlignment="Center"
                                           FontFamily="Aptos" FontSize="8.5" FontWeight="Normal" Opacity="0.62" />""",
    """                                <TextBlock Text="去复习" HorizontalAlignment="Center" FontSize="13"
                                           FontWeight="SemiBold" />""",
)

# 3. 学习计划 subtitle must follow the real target instead of a hardcoded 50
rep(
    """                                <TextBlock Text="每日 50 词" Margin="0,4,0,0" HorizontalAlignment="Center"
                                           FontSize="9" FontWeight="Normal" Foreground="{DynamicResource TextSecondary}" />""",
    """                                <TextBlock x:Name="PlanPerDayText" Text="每日 0 词" Margin="0,4,0,0" HorizontalAlignment="Center"
                                           FontSize="9" FontWeight="Normal" Foreground="{DynamicResource TextSecondary}" />""",
)

io.open(xaml, "w", encoding="utf-8-sig", newline="\r\n").write(s)

# ---- code behind ----
c = io.open(cs, encoding="utf-8-sig").read()


def repc(old, new, n=1):
    global c
    assert c.count(old) == n, (c.count(old), old[:60])
    c = c.replace(old, new)


repc(
    """        TotalStudiedText.Text = $"已学 {_totalStudied:N0}";""",
    """        TotalStudiedText.Text = $"已学 {_totalStudied:N0}";
        PlanPerDayText.Text = $"每日 {_dailyTarget} 词";""",
)

# 4. stop printing the dock state into the footer
repc(
    """        StatusText.Text = $"{(_dockSide == DockSide.Left ? "左" : "右")}侧贴边 · {(_isPinned ? "已固定" : "悬停唤出")}";""",
    """        StatusText.Text = string.Empty;""",
)
repc(
    """        StatusText.Text = "已收起 · 移入边缘唤出";""",
    """        StatusText.Text = string.Empty;""",
)
repc(
    """        else
        {
            StatusText.Text = $"{(_dockSide == DockSide.Left ? "左" : "右")}侧贴边 · 悬停唤出";
        }""",
    """        else
        {
            StatusText.Text = string.Empty;
        }""",
)
repc(
    """            StatusText.Text = "已恢复上次位置";""",
    """            StatusText.Text = string.Empty;""",
)

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("patched xaml + code")
