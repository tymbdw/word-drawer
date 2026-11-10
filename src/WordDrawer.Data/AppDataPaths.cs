namespace WordDrawer.Data;

public static class AppDataPaths
{
    public static string DatabasePath
    {
        get
        {
            var developmentOverride = Environment.GetEnvironmentVariable("WORDDRAWER_DATA_PATH");
            return string.IsNullOrWhiteSpace(developmentOverride)
                ? Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "WordDrawer",
                    "worddrawer.db")
                : Path.GetFullPath(developmentOverride);
        }
    }
}
