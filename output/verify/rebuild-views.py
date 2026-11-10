import io

xaml_path = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
cs_path = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"

s = io.open(xaml_path, encoding="utf-8-sig").read()

old = '''                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="BookListPanel" Margin="0,2,0,8" />
                    </ScrollViewer>
                </Grid>
'''

def row(title, hint, control):
    return f'''                        <Border CornerRadius="16" Background="{{DynamicResource PanelFill}}"
                                BorderBrush="{{DynamicResource PanelStroke}}" BorderThickness="1"
                                Padding="14,11" Margin="0,0,0,8">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Text="{title}" Style="{{StaticResource SettingTitle}}" />
                                    <TextBlock Text="{hint}" Style="{{StaticResource SettingHint}}" />
                                </StackPanel>
                                {control}
                            </Grid>
                        </Border>
'''

segment = lambda name, text, click, margin="6,0,0,0": (
    f'<Button x:Name="{name}" Content="{text}" Style="{{StaticResource SegmentButton}}" '
    f'Margin="{margin}" VerticalAlignment="Center" Click="{click}" />'
)

stepper = lambda label, values: values

new = '''                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Disabled">
                        <StackPanel>

''' + row(
    "材质", "雾银 / 冰蓝 / 夜蓝",
    '''<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Button x:Name="ThemeMistButton" Content="雾银" Style="{StaticResource SegmentButton}" Click="ThemeMist_Click" />
                                    <Button x:Name="ThemeIceButton" Content="冰蓝" Style="{StaticResource SegmentButton}" Margin="6,0,0,0" Click="ThemeIce_Click" />
                                    <Button x:Name="ThemeNightButton" Content="夜蓝" Style="{StaticResource SegmentButton}" Margin="6,0,0,0" Click="ThemeNight_Click" />
                                </StackPanel>''',
) + row(
    "透明度", "越低越透，磨砂仍然生效",
    '''<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Button Content="−" Style="{StaticResource StepperButton}" Click="GlassAlphaDown_Click" />
                                    <TextBlock x:Name="GlassAlphaText" Text="31%" Width="46" TextAlignment="Center"
                                               VerticalAlignment="Center" FontFamily="Baskerville, Georgia"
                                               FontSize="17" Foreground="{DynamicResource TextPrimary}" />
                                    <Button Content="+" Style="{StaticResource StepperButton}" Click="GlassAlphaUp_Click" />
                                </StackPanel>''',
) + row(
    "贴边位置", "拖到屏幕边缘也可以",
    '''<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Button x:Name="DockLeftButton" Content="左" Style="{StaticResource SegmentButton}" Click="DockLeft_Click" />
                                    <Button x:Name="DockRightButton" Content="右" Style="{StaticResource SegmentButton}" Margin="6,0,0,0" Click="DockRight_Click" />
                                </StackPanel>''',
) + row(
    "鼠标离开后收起", "延迟 0.65 秒",
    '''<Button x:Name="AutoHideButton" Content="开" Width="44" Height="26"
                                            HorizontalAlignment="Right" VerticalAlignment="Center"
                                            Style="{StaticResource SegmentButton}" Click="ToggleAutoHide_Click" />''',
) + row(
    "每日新增上限", "10–200，步长 10",
    '''<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Button Content="−" Style="{StaticResource StepperButton}" Click="DailyTargetDown_Click" />
                                    <TextBlock x:Name="DailyTargetText" Text="50" Width="46" TextAlignment="Center"
                                               VerticalAlignment="Center" FontFamily="Baskerville, Georgia"
                                               FontSize="17" Foreground="{DynamicResource TextPrimary}" />
                                    <Button Content="+" Style="{StaticResource StepperButton}" Click="DailyTargetUp_Click" />
                                </StackPanel>''',
) + row(
    "每日复习上限", "50–500，步长 50",
    '''<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Button Content="−" Style="{StaticResource StepperButton}" Click="ReleaseLimitDown_Click" />
                                    <TextBlock x:Name="ReleaseLimitText" Text="200" Width="46" TextAlignment="Center"
                                               VerticalAlignment="Center" FontFamily="Baskerville, Georgia"
                                               FontSize="17" Foreground="{DynamicResource TextPrimary}" />
                                    <Button Content="+" Style="{StaticResource StepperButton}" Click="ReleaseLimitUp_Click" />
                                </StackPanel>''',
) + row(
    "开机自启", "登录后自动运行",
    '''<Button x:Name="StartupButton" Content="关" Width="44" Height="26"
                                            HorizontalAlignment="Right" VerticalAlignment="Center"
                                            Style="{StaticResource SegmentButton}" Click="ToggleStartup_Click" />''',
) + '''                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <Grid x:Name="PlanView" Grid.Row="1" Margin="14,12,14,25" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="44" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>

                    <Grid>
                        <Button Content="←" Width="38" Height="32" HorizontalAlignment="Left"
                                Background="Transparent" BorderThickness="0" Click="BackToHome_Click" />
                        <TextBlock Text="学习计划" HorizontalAlignment="Center" VerticalAlignment="Center"
                                   FontSize="13" FontWeight="SemiBold" Foreground="{DynamicResource TextPrimary}" />
                    </Grid>

                    <StackPanel Grid.Row="1">
                        <Border CornerRadius="18" Background="{DynamicResource PanelFill}"
                                BorderBrush="{DynamicResource PanelStroke}" BorderThickness="1" Padding="16,14">
                            <StackPanel>
                                <TextBlock x:Name="PlanBookText" Text="词书：—" FontSize="11"
                                           Foreground="{DynamicResource TextSecondary}" />

                                <Grid Margin="0,16,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition />
                                        <ColumnDefinition Width="1" />
                                        <ColumnDefinition />
                                    </Grid.ColumnDefinitions>
                                    <StackPanel>
                                        <TextBlock x:Name="PlanRemainingText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="26" Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="剩余未学" Margin="0,5,0,0" FontSize="10"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                    <StackPanel Grid.Column="2" Margin="14,0,0,0">
                                        <TextBlock x:Name="PlanDaysText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="26" Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="按当前速度" Margin="0,5,0,0" FontSize="10"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                </Grid>

                                <Border Height="1" Background="{DynamicResource Divider}" Margin="0,16,0,12" />
                                <TextBlock Text="每日新增与复习上限可在设置页调整。改完之后首页的目标环和待学数量会立刻跟着变。"
                                           FontSize="9.5" TextWrapping="Wrap" LineHeight="17"
                                           Foreground="{DynamicResource TextSecondary}" />
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Grid>

                <Grid x:Name="WordBookView" Grid.Row="1" Margin="14,12,14,25" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="44" />
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>

                    <Grid>
                        <Button Content="←" Width="38" Height="32" HorizontalAlignment="Left"
                                Background="Transparent" BorderThickness="0" Click="BackToHome_Click" />
                        <TextBlock Text="词书" HorizontalAlignment="Center" VerticalAlignment="Center"
                                   FontSize="13" FontWeight="SemiBold" Foreground="{DynamicResource TextPrimary}" />
                    </Grid>

                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                  HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="BookListPanel" Margin="0,2,0,8" />
                    </ScrollViewer>
                </Grid>
'''

assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
io.open(xaml_path, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("views rebuilt")

c = io.open(cs_path, encoding="utf-8-sig").read()
c = c.replace('        PlanBookText.Text = $"词书：{KaoyanWordBook.Name}";',
              '        PlanBookText.Text = $"词书：{_activeBookName}";')
if "_activeBookName" not in c.split("PlanBookText")[0]:
    c = c.replace("    private bool _isFloating;",
                  "    private bool _isFloating;\n    private string _activeBookName = \"—\";", 1)
io.open(cs_path, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("plan book text patched")
