import io

p = r"D:\Window Word\src\WordDrawer.App\MainWindow.xaml.cs"
s = io.open(p, encoding="utf-8-sig").read()


def rep(old, new, n=1):
    global s
    assert s.count(old) == n, (s.count(old), old[:70])
    s = s.replace(old, new)


# 1. remember which positions were answered instead of deleting them
rep(
    "    private readonly List<SessionEntry> _session = [];",
    """    private readonly List<SessionEntry> _session = [];
    private readonly HashSet<int> _answered = [];""",
)

rep(
    """        _isReview = review;
        _wordIndex = 0;""",
    """        _isReview = review;
        _wordIndex = 0;
        _answered.Clear();""",
)

# 2. progress counts answers, not list shrinkage
rep(
    '        SessionProgressText.Text = $"{_sessionTotal - _session.Count + 1} / {_sessionTotal}";',
    '        SessionProgressText.Text = $"{Math.Min(_sessionTotal, _answered.Count + 1)} / {_sessionTotal}";',
)

# 3. answering marks the slot and jumps to the next unanswered one
rep(
    """            _session.RemoveAt(_wordIndex);
            RefreshDashboard();""",
    """            _answered.Add(_wordIndex);
            RefreshDashboard();""",
)

rep(
    """            if (_session.Count == 0)
            {
                FinishSession();
                return;
            }

            if (_wordIndex >= _session.Count)
            {
                _wordIndex = 0;
            }

            ShowCurrentWord(updateStatus: false);""",
    """            if (_answered.Count >= _session.Count)
            {
                FinishSession();
                return;
            }

            var next = NextPendingIndex(_wordIndex);
            if (next < 0)
            {
                FinishSession();
                return;
            }

            _wordIndex = next;
            ShowCurrentWord(updateStatus: false);""",
)

# 4. re-answering a word we already recorded must not write feedback twice
rep(
    """        _isRecordingFeedback = true;
        var entry = _session[_wordIndex];""",
    """        if (_answered.Contains(_wordIndex))
        {
            // Already recorded this one (the user navigated back with ←).
            var pending = NextPendingIndex(_wordIndex);
            if (pending < 0)
            {
                FinishSession();
                return;
            }

            _wordIndex = pending;
            ShowCurrentWord(updateStatus: false);
            return;
        }

        _isRecordingFeedback = true;
        var entry = _session[_wordIndex];""",
)

# 5. helper
rep(
    """    private void ShowCurrentWord(bool updateStatus = true)""",
    """    /// <summary>First unfinished slot after <paramref name="from"/>, or -1 when everything is done.</summary>
    private int NextPendingIndex(int from)
    {
        for (var step = 1; step <= _session.Count; step++)
        {
            var index = (from + step) % _session.Count;
            if (!_answered.Contains(index))
            {
                return index;
            }
        }

        return -1;
    }

    private void ShowCurrentWord(bool updateStatus = true)""",
)

# 6. ← must not wrap around to the last word any more
rep(
    """        _wordIndex = (_wordIndex - 1 + _session.Count) % _session.Count;
        ShowCurrentWord();
        StatusText.Text = "仅返回上一词 · 未记录反馈";""",
    """        if (_wordIndex == 0)
        {
            StatusText.Text = "已经是第一个词";
            return;
        }

        _wordIndex--;
        ShowCurrentWord();
        StatusText.Text = "仅返回上一词 · 未记录反馈";""",
)

io.open(p, "w", encoding="utf-8-sig", newline="\r\n").write(s)
print("session navigation fixed")
