import io
import re

cs = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
c = io.open(cs, encoding="utf-8-sig").read()


def replace_method(src, signature, new_text):
    start = src.index(signature)
    brace = src.index("{", start)
    depth = 0
    end = brace
    while True:
        ch = src[end]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end += 1
                break
        end += 1
    return src[:start] + new_text + src[end:]


# ---------- state ----------
c = c.replace(
    "    private readonly HashSet<int> _answered = [];",
    """    private readonly HashSet<int> _answered = [];
    private readonly List<int> _order = [];
    private readonly List<int> _trace = [];
    private int _tracePos = -1;
    private readonly Dictionary<int, bool> _verdict = [];
    private readonly Dictionary<int, int> _unknownSeen = [];
    private const int RetryGap = 3;
    private const int MaxUnknownPerWord = 2;""",
    1,
)

# ---------- begin ----------
old_begin = """        _session.Clear();
        _session.AddRange(entries);
        _sessionTotal = entries.Count;
        _isReview = review;
        _wordIndex = 0;
        _answered.Clear();"""
new_begin = """        _session.Clear();
        _session.AddRange(entries);
        _sessionTotal = entries.Count;
        _isReview = review;
        _answered.Clear();

        _order.Clear();
        for (var index = 0; index < _session.Count; index++)
        {
            _order.Add(index);
        }

        _trace.Clear();
        _verdict.Clear();
        _unknownSeen.Clear();
        _tracePos = -1;
        _wordIndex = _order.Count > 0 ? _order[0] : 0;
        _trace.Add(_wordIndex);
        _tracePos = 0;"""
assert c.count(old_begin) == 1
c = c.replace(old_begin, new_begin)

# ---------- previous ----------
c = replace_method(c, "    private void PreviousWord()", '''    private void PreviousWord()
    {
        if (_tracePos <= 0)
        {
            StatusText.Text = "已经是第一个词";
            return;
        }

        _tracePos--;
        _wordIndex = _trace[_tracePos];
        ShowCurrentWord();
        StatusText.Text = "仅返回上一词 · 未记录反馈";
    }
''')

# ---------- record + advance ----------
c = replace_method(c, "    private async Task RecordAndMoveAsync(bool known)", '''    private async Task RecordAndMoveAsync(bool known)
    {
        if (_isRecordingFeedback || _order.Count == 0)
        {
            return;
        }

        var index = _wordIndex;
        var rejudge = _verdict.TryGetValue(index, out var previousVerdict);
        _isRecordingFeedback = true;

        try
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var entry = _session[index];
            var card = entry.Card ?? new ReviewCard(entry.Word.Id, today, null, 0, 0, 0, 1);
            var feedback = known ? ReviewFeedback.Known : ReviewFeedback.Unknown;
            var schedule = _reviewScheduler.Schedule(card, feedback, today);

            await _database.RecordFeedbackAsync(
                entry.Word.Id,
                known ? WordFeedback.Known : WordFeedback.Unknown,
                DateTimeOffset.Now,
                schedule.NextDueDate,
                schedule.Stability,
                schedule.Difficulty,
                schedule.ConsecutiveKnown,
                schedule.Repetitions);

            // "认识" is what counts as learned; "不认识" must not inflate the daily total.
            if (known)
            {
                if (!rejudge)
                {
                    CountStudiedBy(+1);          // first verdict, the data layer already added one
                }
                else if (!previousVerdict)
                {
                    CountStudiedBy(+1);          // flipped from unknown: compensate explicitly
                    await _database.AdjustDailyStudiedAsync(today, +1);
                }
            }
            else if (rejudge && previousVerdict)
            {
                CountStudiedBy(-1);              // flipped from known: take it back
                await _database.AdjustDailyStudiedAsync(today, -1);
            }

            _verdict[index] = known;
            _order.Remove(index);

            if (!known)
            {
                var seen = _unknownSeen.TryGetValue(index, out var times) ? times + 1 : 1;
                _unknownSeen[index] = seen;
                if (seen < MaxUnknownPerWord)
                {
                    // bring it back after a few other words instead of at the very end
                    _order.Insert(Math.Min(RetryGap, _order.Count), index);
                }
            }

            if (_isReview && known)
            {
                _reviewRemaining = Math.Max(0, _reviewRemaining - 1);
            }

            RefreshDashboard();
            StatusText.Text = known
                ? $"已保存：认识 · {schedule.NextDueDate:MM-dd} 再复习"
                : _unknownSeen[index] < MaxUnknownPerWord
                    ? $"不认识 · {RetryGap} 个词后再考一次"
                    : "不认识 · 明天再复习";

            if (_order.Count == 0)
            {
                FinishSession();
                return;
            }

            Advance(_order[0]);
        }
        catch (Exception exception)
        {
            StatusText.Text = $"保存失败，未切换单词：{exception.Message}";
        }
        finally
        {
            _isRecordingFeedback = false;
        }
    }

    private void CountStudiedBy(int delta)
    {
        _todayStudied = Math.Max(0, _todayStudied + delta);
        _totalStudied = Math.Max(0, _totalStudied + delta);
        if (delta < 0)
        {
            _newRemaining++;
        }
        else
        {
            _newRemaining = Math.Max(0, _newRemaining - 1);
        }
    }

    /// <summary>Shows the next queued word and records it in the back-navigation trace.</summary>
    private void Advance(int index)
    {
        if (_tracePos >= 0 && _tracePos < _trace.Count - 1)
        {
            _trace.RemoveRange(_tracePos + 1, _trace.Count - _tracePos - 1);
        }

        _wordIndex = index;
        _trace.Add(index);
        _tracePos = _trace.Count - 1;
        ShowCurrentWord(updateStatus: false);
    }
''')

# ---------- finish also needs the guard ----------
c = c.replace(
    """    private void FinishSession()
    {
        var completed = _sessionTotal;
        FlushStudyTime();""",
    """    private void FinishSession()
    {
        var completed = _todayStudied;
        FlushStudyTime();""",
    1,
)

io.open(cs, "w", encoding="utf-8-sig", newline="\r\n").write(c)
print("session logic rewritten")

# ---------------- data layer ----------------
db = r"D:\Window Word\src\WordDrawer.Data\WordDrawerDatabase.cs"
d = io.open(db, encoding="utf-8-sig").read()

old_cond = """        if (isInitialStudy)
        {
            var statsCommand = connection.CreateCommand();"""
new_cond = """        // Only a word the user actually recognised counts as "studied today".
        if (isInitialStudy && feedback == WordFeedback.Known)
        {
            var statsCommand = connection.CreateCommand();"""
assert d.count(old_cond) == 1
d = d.replace(old_cond, new_cond)

anchor = "    /// <summary>Adds counted study time to a day's total.</summary>"
add = '''    /// <summary>Adds or removes studied-word counts, used when the user changes an answer.</summary>
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

'''
assert d.count(anchor) == 1
d = d.replace(anchor, add + anchor)
io.open(db, "w", encoding="utf-8-sig", newline="\r\n").write(d)
print("data layer updated")
