"""Extract the Kaoyan (ky) subset from ECDICT into a compact bundled wordbook.

Source: https://github.com/skywind3000/ECDICT (MIT License)
Only the English headword, part of speech and a trimmed Chinese gloss are kept.
"""

import csv
import io
import json
import re

POS_ALIASES = [
    ("vt.&vi.", "v."), ("vi.&vt.", "v."), ("vt.", "vt."), ("vi.", "vi."),
    ("adj.", "adj."), ("adv.", "adv."), ("prep.", "prep."), ("conj.", "conj."),
    ("pron.", "pron."), ("num.", "num."), ("art.", "art."), ("int.", "int."),
    ("aux.", "aux."), ("abbr.", "abbr."), ("n.", "n."), ("v.", "v."),
    ("a.", "adj."), ("ad.", "adv."),
]
POS_RE = re.compile(r"^\s*(vt\.&vi\.|vi\.&vt\.|vt\.|vi\.|adj\.|adv\.|prep\.|conj\.|pron\.|num\.|art\.|int\.|aux\.|abbr\.|n\.|v\.|a\.|ad\.)\s*")
DROP_SEGMENT = re.compile(r"^\[[^\]]*\]")

MAX_MEANING = 44


def clean(word: str, translation: str) -> tuple[str, str] | None:
    if not translation:
        return None

    segments = [s.strip() for s in translation.split("\\n")]
    segments = [s for s in segments if s and not DROP_SEGMENT.match(s)]
    if not segments:
        return None

    # Prefer the segment that carries a part-of-speech marker; otherwise the first one.
    body = next((s for s in segments if POS_RE.match(s)), segments[0])

    pos = ""
    match = POS_RE.match(body)
    if match:
        raw = match.group(1)
        pos = next(mapped for alias, mapped in POS_ALIASES if alias == raw)
        body = body[match.end():]

    body = body.replace(", ", "，").replace(",", "，")
    body = re.sub(r"\s+", " ", body).strip(" ；，")
    if not body:
        return None

    # Drop repeated senses such as "发生，发生，恰巧".
    seen = []
    for piece in body.split("，"):
        piece = piece.strip()
        if piece and piece not in seen:
            seen.append(piece)
    body = "，".join(seen)
    if not body:
        return None

    if len(body) > MAX_MEANING:
        cut = body.rfind("，", 0, MAX_MEANING)
        if cut < MAX_MEANING // 2:
            cut = MAX_MEANING
        body = body[:cut].rstrip("，") + "…"

    return pos, body


def main() -> None:
    rows = []
    with io.open("ecdict.csv", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            tags = (row.get("tag") or "").split()
            if "ky" not in tags:
                continue

            word = (row.get("word") or "").strip()
            if not word or len(word) > 22 or any(ch.isdigit() for ch in word):
                continue
            if not all(ch.isascii() and (ch.isalpha() or ch in " -'.") for ch in word):
                continue

            cleaned = clean(word, row.get("translation") or "")
            if cleaned is None:
                continue

            pos, meaning = cleaned
            try:
                frq = int(row.get("frq") or 0)
            except ValueError:
                frq = 0

            rows.append({
                "w": word,
                "p": pos,
                "m": meaning,
                "f": frq,
            })

    # Most frequent first (frq is a frequency rank; 0 means "not ranked").
    rows.sort(key=lambda r: (r["f"] if r["f"] > 0 else 10 ** 9, r["w"].lower()))
    for index, row in enumerate(rows, start=1):
        row["i"] = index
        del row["f"]

    with io.open("kaoyan-2027.json", "w", encoding="utf-8", newline="\n") as out:
        json.dump(rows, out, ensure_ascii=False, separators=(",", ":"))

    print("words:", len(rows))
    for row in rows[:8]:
        print(" ", row["i"], row["w"], row["p"], row["m"])
    for row in rows[-4:]:
        print(" ", row["i"], row["w"], row["p"], row["m"])


if __name__ == "__main__":
    main()
