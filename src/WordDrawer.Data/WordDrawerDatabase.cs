using System.Globalization;
using Microsoft.Data.Sqlite;
using WordDrawer.Core;
using WordDrawer.Review;

namespace WordDrawer.Data;

public sealed class WordDrawerDatabase
{
    private const int SchemaVersion = 2;
    private readonly string _connectionString;

    public WordDrawerDatabase(string databasePath)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(databasePath);
        DatabasePath = Path.GetFullPath(databasePath);
        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = DatabasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
            ForeignKeys = true,
            Pooling = false
        }.ToString();
    }

    public string DatabasePath { get; }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        var directory = Path.GetDirectoryName(DatabasePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS WordBooks (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Name TEXT NOT NULL UNIQUE,
                Source TEXT NOT NULL,
                IsActive INTEGER NOT NULL DEFAULT 0 CHECK (IsActive IN (0, 1)),
                CreatedUtc TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS Words (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                WordBookId INTEGER NOT NULL,
                Sequence INTEGER NOT NULL,
                English TEXT NOT NULL COLLATE NOCASE,
                PartOfSpeech TEXT NOT NULL,
                Meaning TEXT NOT NULL,
                ExamFrequency REAL NOT NULL DEFAULT 0,
                FOREIGN KEY (WordBookId) REFERENCES WordBooks(Id) ON DELETE CASCADE,
                UNIQUE (WordBookId, Sequence),
                UNIQUE (WordBookId, English)
            );

            CREATE TABLE IF NOT EXISTS StudyStates (
                WordId INTEGER PRIMARY KEY,
                FirstStudiedUtc TEXT,
                LastReviewedUtc TEXT,
                NextDueDate TEXT,
                ReleasedDate TEXT,
                KnownCount INTEGER NOT NULL DEFAULT 0,
                UnknownCount INTEGER NOT NULL DEFAULT 0,
                ConsecutiveKnown INTEGER NOT NULL DEFAULT 0,
                Stability REAL NOT NULL DEFAULT 1,
                Difficulty REAL NOT NULL DEFAULT 0,
                Repetitions INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (WordId) REFERENCES Words(Id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS ReviewEvents (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                WordId INTEGER NOT NULL,
                OccurredUtc TEXT NOT NULL,
                Feedback INTEGER NOT NULL CHECK (Feedback IN (0, 1)),
                IsInitialStudy INTEGER NOT NULL CHECK (IsInitialStudy IN (0, 1)),
                FOREIGN KEY (WordId) REFERENCES Words(Id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS DailyPlans (
                Date TEXT PRIMARY KEY,
                NewWordTarget INTEGER NOT NULL CHECK (NewWordTarget > 0)
            );

            CREATE TABLE IF NOT EXISTS DailyStats (
                Date TEXT PRIMARY KEY,
                UniqueWordsStudied INTEGER NOT NULL DEFAULT 0,
                EffectiveSeconds INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS AppSettings (
                Key TEXT PRIMARY KEY,
                Value TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS IX_Words_BookSequence ON Words (WordBookId, Sequence);
            CREATE INDEX IF NOT EXISTS IX_StudyStates_NextDueDate ON StudyStates (NextDueDate);
            CREATE INDEX IF NOT EXISTS IX_ReviewEvents_WordTime ON ReviewEvents (WordId, OccurredUtc);
            """;
        await command.ExecuteNonQueryAsync(cancellationToken);

        // v1 databases predate the FSRS columns.
        await EnsureColumnAsync(connection, "StudyStates", "Difficulty", "REAL NOT NULL DEFAULT 0", cancellationToken);
        await EnsureColumnAsync(connection, "StudyStates", "Repetitions", "INTEGER NOT NULL DEFAULT 0", cancellationToken);

        await using var versionCommand = connection.CreateCommand();
        versionCommand.CommandText = $"PRAGMA user_version = {SchemaVersion};";
        await versionCommand.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<long> SeedWordBookAsync(
        string name,
        string source,
        IReadOnlyCollection<StudyWord> words,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(source);

        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var deactivate = connection.CreateCommand();
        deactivate.Transaction = transaction;
        deactivate.CommandText = "UPDATE WordBooks SET IsActive = 0;";
        await deactivate.ExecuteNonQueryAsync(cancellationToken);

        var bookCommand = connection.CreateCommand();
        bookCommand.Transaction = transaction;
        bookCommand.CommandText = """
            INSERT INTO WordBooks (Name, Source, IsActive, CreatedUtc)
            VALUES ($name, $source, 1, $createdUtc)
            ON CONFLICT(Name) DO UPDATE SET Source = excluded.Source, IsActive = 1
            RETURNING Id;
            """;
        bookCommand.Parameters.AddWithValue("$name", name);
        bookCommand.Parameters.AddWithValue("$source", source);
        bookCommand.Parameters.AddWithValue("$createdUtc", DateTimeOffset.UtcNow.ToString("O"));
        var bookId = Convert.ToInt64(await bookCommand.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);

        var wordCommand = connection.CreateCommand();
        wordCommand.Transaction = transaction;
        wordCommand.CommandText = """
            INSERT INTO Words (WordBookId, Sequence, English, PartOfSpeech, Meaning)
            VALUES ($bookId, $sequence, $english, $partOfSpeech, $meaning)
            ON CONFLICT(WordBookId, English) DO UPDATE SET
                Sequence = excluded.Sequence,
                PartOfSpeech = excluded.PartOfSpeech,
                Meaning = excluded.Meaning;
            """;
        var bookIdParameter = wordCommand.Parameters.Add("$bookId", SqliteType.Integer);
        var sequenceParameter = wordCommand.Parameters.Add("$sequence", SqliteType.Integer);
        var englishParameter = wordCommand.Parameters.Add("$english", SqliteType.Text);
        var partOfSpeechParameter = wordCommand.Parameters.Add("$partOfSpeech", SqliteType.Text);
        var meaningParameter = wordCommand.Parameters.Add("$meaning", SqliteType.Text);
        bookIdParameter.Value = bookId;

        foreach (var word in words.OrderBy(word => word.Sequence))
        {
            sequenceParameter.Value = word.Sequence;
            englishParameter.Value = word.English.Trim();
            partOfSpeechParameter.Value = word.PartOfSpeech.Trim();
            meaningParameter.Value = word.Meaning.Trim();
            await wordCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return bookId;
    }

    public async Task<IReadOnlyList<StudyWord>> GetNextUnstudiedWordsAsync(
        int limit,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limit);

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT w.Id, w.Sequence, w.English, w.PartOfSpeech, w.Meaning
            FROM Words w
            INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1
            LEFT JOIN StudyStates s ON s.WordId = w.Id
            WHERE s.FirstStudiedUtc IS NULL
            ORDER BY w.Sequence
            LIMIT $limit;
            """;
        command.Parameters.AddWithValue("$limit", limit);

        var result = new List<StudyWord>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new StudyWord(
                reader.GetInt64(0),
                reader.GetInt32(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetString(4)));
        }

        return result;
    }

    public async Task RecordFeedbackAsync(
        long wordId,
        WordFeedback feedback,
        DateTimeOffset occurredAt,
        DateOnly nextDueDate,
        double stability,
        double difficulty,
        int consecutiveKnown,
        int repetitions,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        var firstStudyCommand = connection.CreateCommand();
        firstStudyCommand.Transaction = transaction;
        firstStudyCommand.CommandText = "SELECT FirstStudiedUtc IS NULL FROM StudyStates WHERE WordId = $wordId;";
        firstStudyCommand.Parameters.AddWithValue("$wordId", wordId);
        var existingState = await firstStudyCommand.ExecuteScalarAsync(cancellationToken);
        var isInitialStudy = existingState is null || existingState == DBNull.Value || Convert.ToInt32(existingState) == 1;

        var stateCommand = connection.CreateCommand();
        stateCommand.Transaction = transaction;
        stateCommand.CommandText = """
            INSERT INTO StudyStates (
                WordId, FirstStudiedUtc, LastReviewedUtc, NextDueDate,
                KnownCount, UnknownCount, ConsecutiveKnown, Stability, Difficulty, Repetitions)
            VALUES (
                $wordId, $occurredUtc, $occurredUtc, $nextDueDate,
                $knownIncrement, $unknownIncrement, $consecutiveKnown, $stability, $difficulty, $repetitions)
            ON CONFLICT(WordId) DO UPDATE SET
                FirstStudiedUtc = COALESCE(StudyStates.FirstStudiedUtc, excluded.FirstStudiedUtc),
                LastReviewedUtc = excluded.LastReviewedUtc,
                NextDueDate = excluded.NextDueDate,
                ReleasedDate = NULL,
                KnownCount = StudyStates.KnownCount + $knownIncrement,
                UnknownCount = StudyStates.UnknownCount + $unknownIncrement,
                ConsecutiveKnown = excluded.ConsecutiveKnown,
                Stability = excluded.Stability,
                Difficulty = excluded.Difficulty,
                Repetitions = excluded.Repetitions;
            """;
        stateCommand.Parameters.AddWithValue("$wordId", wordId);
        stateCommand.Parameters.AddWithValue("$occurredUtc", occurredAt.ToUniversalTime().ToString("O"));
        stateCommand.Parameters.AddWithValue("$nextDueDate", nextDueDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        stateCommand.Parameters.AddWithValue("$knownIncrement", feedback == WordFeedback.Known ? 1 : 0);
        stateCommand.Parameters.AddWithValue("$unknownIncrement", feedback == WordFeedback.Unknown ? 1 : 0);
        stateCommand.Parameters.AddWithValue("$consecutiveKnown", consecutiveKnown);
        stateCommand.Parameters.AddWithValue("$stability", stability);
        stateCommand.Parameters.AddWithValue("$difficulty", difficulty);
        stateCommand.Parameters.AddWithValue("$repetitions", repetitions);
        await stateCommand.ExecuteNonQueryAsync(cancellationToken);

        var eventCommand = connection.CreateCommand();
        eventCommand.Transaction = transaction;
        eventCommand.CommandText = """
            INSERT INTO ReviewEvents (WordId, OccurredUtc, Feedback, IsInitialStudy)
            VALUES ($wordId, $occurredUtc, $feedback, $isInitialStudy);
            """;
        eventCommand.Parameters.AddWithValue("$wordId", wordId);
        eventCommand.Parameters.AddWithValue("$occurredUtc", occurredAt.ToUniversalTime().ToString("O"));
        eventCommand.Parameters.AddWithValue("$feedback", (int)feedback);
        eventCommand.Parameters.AddWithValue("$isInitialStudy", isInitialStudy ? 1 : 0);
        await eventCommand.ExecuteNonQueryAsync(cancellationToken);

        // Only a word the user actually recognised counts as "studied today".
        if (isInitialStudy && feedback == WordFeedback.Known)
        {
            var statsCommand = connection.CreateCommand();
            statsCommand.Transaction = transaction;
            statsCommand.CommandText = """
                INSERT INTO DailyStats (Date, UniqueWordsStudied, EffectiveSeconds)
                VALUES ($date, 1, 0)
                ON CONFLICT(Date) DO UPDATE SET
                    UniqueWordsStudied = DailyStats.UniqueWordsStudied + 1;
                """;
            statsCommand.Parameters.AddWithValue("$date", DateOnly.FromDateTime(occurredAt.LocalDateTime).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
            await statsCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<DashboardSnapshot> GetDashboardAsync(
        DateOnly today,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                (SELECT COUNT(*) FROM StudyStates s
                 INNER JOIN Words w ON w.Id = s.WordId
                 INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1
                 WHERE s.FirstStudiedUtc IS NOT NULL),
                COALESCE((SELECT UniqueWordsStudied FROM DailyStats WHERE Date = $today), 0),
                (SELECT COUNT(*) FROM StudyStates s
                 INNER JOIN Words w ON w.Id = s.WordId
                 INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1
                 WHERE s.NextDueDate <= $today),
                COALESCE((SELECT SUM(EffectiveSeconds) FROM DailyStats), 0);
            """;
        command.Parameters.AddWithValue("$today", today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        await reader.ReadAsync(cancellationToken);
        return new DashboardSnapshot(reader.GetInt32(0), reader.GetInt32(1), reader.GetInt32(2), reader.GetInt64(3));
    }

    public async Task<int> GetReviewEventCountAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM ReviewEvents;";
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Loads every word whose next due date has arrived, with the memory state needed to
    /// reschedule it. Ordering happens in <c>ReviewScheduler.BuildQueue</c>.
    /// </summary>
    public async Task<IReadOnlyList<ReviewQueueItem>> GetDueReviewItemsAsync(
        DateOnly today,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT w.Id, w.Sequence, w.English, w.PartOfSpeech, w.Meaning,
                   s.NextDueDate, s.ReleasedDate, s.KnownCount, s.UnknownCount,
                   s.ConsecutiveKnown, s.Stability, s.Difficulty, s.Repetitions, s.LastReviewedUtc
            FROM Words w
            INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1
            INNER JOIN StudyStates s ON s.WordId = w.Id
            WHERE s.NextDueDate IS NOT NULL AND s.NextDueDate <= $today
            ORDER BY s.NextDueDate, w.Sequence;
            """;
        command.Parameters.AddWithValue("$today", today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));

        var result = new List<ReviewQueueItem>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var due = DateOnly.ParseExact(reader.GetString(5), "yyyy-MM-dd", CultureInfo.InvariantCulture);
            var released = reader.IsDBNull(6)
                ? (DateOnly?)null
                : DateOnly.ParseExact(reader.GetString(6), "yyyy-MM-dd", CultureInfo.InvariantCulture);
            var lastReviewed = reader.IsDBNull(13)
                ? (DateOnly?)null
                : DateOnly.FromDateTime(DateTimeOffset.Parse(reader.GetString(13), CultureInfo.InvariantCulture).LocalDateTime);

            var card = new ReviewCard(
                reader.GetInt64(0),
                due,
                released,
                reader.GetInt32(7),
                reader.GetInt32(8),
                reader.GetInt32(9),
                reader.GetDouble(10),
                false,
                reader.GetDouble(11),
                lastReviewed,
                reader.GetInt32(12));

            result.Add(new ReviewQueueItem(
                reader.GetInt64(0),
                reader.GetInt32(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetString(4),
                card));
        }

        return result;
    }

    /// <summary>Marks words as released today so tomorrow's release budget is computed correctly.</summary>
    public async Task MarkReleasedAsync(
        IReadOnlyCollection<long> wordIds,
        DateOnly today,
        CancellationToken cancellationToken = default)
    {
        if (wordIds.Count == 0)
        {
            return;
        }

        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

        foreach (var wordId in wordIds)
        {
            var command = connection.CreateCommand();
            command.Transaction = transaction;
            command.CommandText = "UPDATE StudyStates SET ReleasedDate = $released WHERE WordId = $wordId AND ReleasedDate IS NULL;";
            command.Parameters.AddWithValue("$released", today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
            command.Parameters.AddWithValue("$wordId", wordId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    /// <summary>Returns the persisted memory state for a word, or null when it was never studied.</summary>
    public async Task<ReviewCard?> GetCardAsync(long wordId, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT NextDueDate, ReleasedDate, KnownCount, UnknownCount, ConsecutiveKnown,
                   Stability, Difficulty, Repetitions, LastReviewedUtc
            FROM StudyStates
            WHERE WordId = $wordId;
            """;
        command.Parameters.AddWithValue("$wordId", wordId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var due = reader.IsDBNull(0)
            ? DateOnly.FromDateTime(DateTime.Today)
            : DateOnly.ParseExact(reader.GetString(0), "yyyy-MM-dd", CultureInfo.InvariantCulture);
        var released = reader.IsDBNull(1)
            ? (DateOnly?)null
            : DateOnly.ParseExact(reader.GetString(1), "yyyy-MM-dd", CultureInfo.InvariantCulture);
        var lastReviewed = reader.IsDBNull(8)
            ? (DateOnly?)null
            : DateOnly.FromDateTime(DateTimeOffset.Parse(reader.GetString(8), CultureInfo.InvariantCulture).LocalDateTime);

        return new ReviewCard(
            wordId,
            due,
            released,
            reader.GetInt32(2),
            reader.GetInt32(3),
            reader.GetInt32(4),
            reader.GetDouble(5),
            false,
            reader.GetDouble(6),
            lastReviewed,
            reader.GetInt32(7));
    }

    /// <summary>Plan value used when the user never configured a daily target.</summary>
    public const int DefaultDailyNewWordTarget = 50;

    /// <summary>Returns the most recent daily new-word target on or before <paramref name="date"/>.</summary>
    public async Task<int> GetDailyNewWordTargetAsync(DateOnly date, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT NewWordTarget FROM DailyPlans
            WHERE Date <= $date
            ORDER BY Date DESC
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("$date", date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));

        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value is null || value == DBNull.Value
            ? DefaultDailyNewWordTarget
            : Convert.ToInt32(value, CultureInfo.InvariantCulture);
    }

    public async Task SetDailyNewWordTargetAsync(
        DateOnly date,
        int target,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(target);

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            INSERT INTO DailyPlans (Date, NewWordTarget) VALUES ($date, $target)
            ON CONFLICT(Date) DO UPDATE SET NewWordTarget = excluded.NewWordTarget;
            """;
        command.Parameters.AddWithValue("$date", date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        command.Parameters.AddWithValue("$target", target);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>Every wordbook with its word count and how many of them were studied at least once.</summary>
    public async Task<IReadOnlyList<WordBookSummary>> GetWordBookSummariesAsync(
        CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT b.Id,
                   b.Name,
                   b.Source,
                   b.IsActive,
                   (SELECT COUNT(*) FROM Words w WHERE w.WordBookId = b.Id),
                   (SELECT COUNT(*) FROM Words w
                    JOIN StudyStates s ON s.WordId = w.Id
                    WHERE w.WordBookId = b.Id AND s.FirstStudiedUtc IS NOT NULL)
            FROM WordBooks b
            ORDER BY b.Id;
            """;

        var result = new List<WordBookSummary>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new WordBookSummary(
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetInt32(3) == 1,
                reader.GetInt32(4),
                reader.GetInt32(5)));
        }

        return result;
    }

    /// <summary>Makes exactly one wordbook active.</summary>
    public async Task SetActiveWordBookAsync(int wordBookId, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var clear = connection.CreateCommand())
        {
            clear.Transaction = (Microsoft.Data.Sqlite.SqliteTransaction)transaction;
            clear.CommandText = "UPDATE WordBooks SET IsActive = 0 WHERE IsActive = 1;";
            await clear.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var set = connection.CreateCommand())
        {
            set.Transaction = (Microsoft.Data.Sqlite.SqliteTransaction)transaction;
            set.CommandText = "UPDATE WordBooks SET IsActive = 1 WHERE Id = $id;";
            set.Parameters.AddWithValue("$id", wordBookId);
            await set.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    /// <summary>True when a wordbook with this exact name is already stored.</summary>
    public async Task<bool> WordBookExistsAsync(string name, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM WordBooks WHERE Name = $name;";
        command.Parameters.AddWithValue("$name", name);
        var count = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken) ?? 0L);
        return count > 0;
    }

    /// <summary>Adds or removes studied-word counts, used when the user changes an answer.</summary>
    public async Task AdjustDailyStudiedAsync(
        DateOnly date,
        int delta,
        CancellationToken cancellationToken = default)
    {
        if (delta == 0)
        {
            return;
        }

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            INSERT INTO DailyStats (Date, UniqueWordsStudied, EffectiveSeconds)
            VALUES ($date, MAX(0, $delta), 0)
            ON CONFLICT(Date) DO UPDATE SET
                UniqueWordsStudied = MAX(0, DailyStats.UniqueWordsStudied + $delta);
            """;
        command.Parameters.AddWithValue("$date", date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        command.Parameters.AddWithValue("$delta", delta);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>Adds counted study time to a day's total.</summary>
    public async Task AddEffectiveSecondsAsync(
        DateOnly date,
        long seconds,
        CancellationToken cancellationToken = default)
    {
        if (seconds <= 0)
        {
            return;
        }

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            INSERT INTO DailyStats (Date, UniqueWordsStudied, EffectiveSeconds)
            VALUES ($date, 0, $seconds)
            ON CONFLICT(Date) DO UPDATE SET
                EffectiveSeconds = DailyStats.EffectiveSeconds + $seconds;
            """;
        command.Parameters.AddWithValue("$date", date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        command.Parameters.AddWithValue("$seconds", seconds);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>Per-day study totals for the last <paramref name="days"/> days ending at <paramref name="endDate"/>.</summary>
    public async Task<IReadOnlyList<DailyStat>> GetRecentDailyStatsAsync(
        DateOnly endDate,
        int days,
        CancellationToken cancellationToken = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(days);

        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT Date, UniqueWordsStudied, EffectiveSeconds FROM DailyStats
            WHERE Date <= $end AND Date > $start
            ORDER BY Date;
            """;
        var start = endDate.AddDays(-days);
        command.Parameters.AddWithValue("$end", endDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        command.Parameters.AddWithValue("$start", start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));

        var result = new List<DailyStat>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new DailyStat(
                DateOnly.ParseExact(reader.GetString(0), "yyyy-MM-dd", CultureInfo.InvariantCulture),
                reader.GetInt32(1),
                reader.GetInt64(2)));
        }

        return result;
    }

    /// <summary>Reads a key-value setting, or null when it was never written.</summary>
    public async Task<string?> GetSettingAsync(string key, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT Value FROM AppSettings WHERE Key = $key;";
        command.Parameters.AddWithValue("$key", key);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value is null || value == DBNull.Value ? null : Convert.ToString(value, CultureInfo.InvariantCulture);
    }

    public async Task SetSettingAsync(string key, string value, CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            INSERT INTO AppSettings (Key, Value) VALUES ($key, $value)
            ON CONFLICT(Key) DO UPDATE SET Value = excluded.Value;
            """;
        command.Parameters.AddWithValue("$key", key);
        command.Parameters.AddWithValue("$value", value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>Counts words in the active book, used to decide whether the bundled book needs seeding.</summary>
    public async Task<int> CountWordsInActiveBookAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COUNT(*)
            FROM Words w
            INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1;
            """;
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);
    }

    /// <summary>Counts words in the active book that have never been studied.</summary>
    public async Task<int> CountUnstudiedWordsAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COUNT(*)
            FROM Words w
            INNER JOIN WordBooks b ON b.Id = w.WordBookId AND b.IsActive = 1
            LEFT JOIN StudyStates s ON s.WordId = w.Id
            WHERE s.FirstStudiedUtc IS NULL;
            """;
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), CultureInfo.InvariantCulture);
    }

    private static async Task EnsureColumnAsync(
        SqliteConnection connection,
        string table,
        string column,
        string definition,
        CancellationToken cancellationToken)
    {
        await using var info = connection.CreateCommand();
        info.CommandText = $"PRAGMA table_info({table});";
        await using var reader = await info.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            if (string.Equals(reader.GetString(1), column, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
        }

        await reader.DisposeAsync();
        await using var alter = connection.CreateCommand();
        alter.CommandText = $"ALTER TABLE {table} ADD COLUMN {column} {definition};";
        await alter.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task<SqliteConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new SqliteConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}
