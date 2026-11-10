import io

p = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml"
s = io.open(p, encoding="utf-8-sig").read()

old = """                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="*" />
                                    <RowDefinition Height="4" />
                                </Grid.RowDefinitions>
                                <TextBlock Text="今日任务" FontSize="11" Foreground="{DynamicResource TextSecondary}" />
                                <Grid Grid.Row="1" Margin="0,12,0,17">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition />
                                        <ColumnDefinition Width="31" />
                                        <ColumnDefinition Width="1" />
                                        <ColumnDefinition Width="31" />
                                        <ColumnDefinition />
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" VerticalAlignment="Bottom">
                                        <TextBlock x:Name="NewCountText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="36" FontWeight="Normal" LineHeight="34"
                                                   Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="仍需学习" Margin="0,7,0,0" FontSize="11"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                    <Border Grid.Column="2" Height="44" VerticalAlignment="Bottom"
                                            Background="#24425D70" />
                                    <StackPanel Grid.Column="4" VerticalAlignment="Bottom">
                                        <TextBlock x:Name="ReviewCountText" Text="—" FontFamily="Baskerville, Georgia"
                                                   FontSize="36" FontWeight="Normal" LineHeight="34"
                                                   Foreground="{DynamicResource TextPrimary}" />
                                        <TextBlock Text="等待复习" Margin="0,7,0,0" FontSize="11"
                                                   Foreground="{DynamicResource TextSecondary}" />
                                    </StackPanel>
                                </Grid>
                                <ProgressBar x:Name="DailyProgressBar" Grid.Row="2" Style="{StaticResource HomeProgress}"
                                             Minimum="0" Maximum="50" Value="0" />
                            </Grid>"""

new = """                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="*" />
                                </Grid.RowDefinitions>
                                <Grid>
                                    <TextBlock Text="今日任务" FontSize="11" Foreground="{DynamicResource TextSecondary}" />
                                    <TextBlock x:Name="TodayTargetText" Text="0 / 50" HorizontalAlignment="Right"
                                               FontSize="10" Foreground="{DynamicResource TextSecondary}" />
                                </Grid>
                                <Grid Grid.Row="1" Margin="0,8,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition />
                                        <ColumnDefinition Width="78" />
                                    </Grid.ColumnDefinitions>
                                    <Grid Margin="0,0,6,0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition />
                                            <ColumnDefinition Width="1" />
                                            <ColumnDefinition />
                                        </Grid.ColumnDefinitions>
                                        <StackPanel VerticalAlignment="Center">
                                            <TextBlock x:Name="NewCountText" Text="—" FontFamily="Baskerville, Georgia"
                                                       FontSize="34" FontWeight="Normal" LineHeight="32"
                                                       Foreground="{DynamicResource TextPrimary}" />
                                            <TextBlock Text="仍需学习" Margin="0,6,0,0" FontSize="11"
                                                       Foreground="{DynamicResource TextSecondary}" />
                                        </StackPanel>
                                        <Border Grid.Column="1" Height="40" VerticalAlignment="Center"
                                                Background="#24425D70" />
                                        <StackPanel Grid.Column="2" Margin="10,0,0,0" VerticalAlignment="Center">
                                            <TextBlock x:Name="ReviewCountText" Text="—" FontFamily="Baskerville, Georgia"
                                                       FontSize="34" FontWeight="Normal" LineHeight="32"
                                                       Foreground="{DynamicResource TextPrimary}" />
                                            <TextBlock Text="等待复习" Margin="0,6,0,0" FontSize="11"
                                                       Foreground="{DynamicResource TextSecondary}" />
                                        </StackPanel>
                                    </Grid>
                                    <Grid Grid.Column="1" Width="72" Height="72" VerticalAlignment="Center"
                                          HorizontalAlignment="Right">
                                        <Ellipse Stroke="#2E425D70" StrokeThickness="6" />
                                        <Ellipse x:Name="ProgressArc" Stroke="{DynamicResource Accent}" StrokeThickness="6"
                                                 StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                                 RenderTransformOrigin="0.5,0.5">
                                            <Ellipse.RenderTransform>
                                                <RotateTransform Angle="-90" />
                                            </Ellipse.RenderTransform>
                                        </Ellipse>
                                        <TextBlock x:Name="ProgressRingText" Text="0" HorizontalAlignment="Center"
                                                   VerticalAlignment="Center" FontFamily="Baskerville, Georgia"
                                                   FontSize="20" Foreground="{DynamicResource TextPrimary}" />
                                    </Grid>
                                </Grid>
                            </Grid>"""

assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("ring layout written")
