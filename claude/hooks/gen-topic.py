#!/usr/bin/env python3
"""Stop hook: generate a topic slug from word frequency across user messages.

Incremental: tracks byte offset into the transcript so each run only reads
new bytes. Caches word frequencies in /tmp keyed by session_id.
"""

import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

NOISE_WORDS = frozenset(
    "the a an is to and or in on of for it my me i can we do this that with"
    " also just please not are be was were been has have had will would should"
    " could may might shall let its get got set how what why when where which"
    " who whom ok yes no make makes made check see use add don doesn didn t s"
    " re ve ll about want need try but".split()
)

MIN_WORD_LEN = 3
TOP_N = 5
MAX_SLUG_LEN = 40
TMP = Path("/tmp")


def extract_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(
            b["text"] for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return ""


def tokenize(text: str) -> list[str]:
    return [
        w for w in re.findall(r"[a-z0-9]+", text.lower())
        if len(w) >= MIN_WORD_LEN and w not in NOISE_WORDS
    ]


def atomic_write(path: Path, data: str):
    tmp = path.with_name(f"{path.name}.{os.getpid()}")
    tmp.write_text(data)
    tmp.rename(path)


def main():
    hook_input = json.load(sys.stdin)

    session_id = hook_input.get("session_id")
    if not session_id:
        return

    # Resolve transcript path
    transcript = Path(hook_input.get("transcript_path", ""))
    if not transcript.is_file():
        cwd = hook_input.get("cwd", "")
        if not cwd:
            return
        transcript = Path.home() / ".claude/projects" / cwd.replace("/", "-") / f"{session_id}.jsonl"
    if not transcript.is_file():
        return

    topic_file = TMP / f"claude-topic-{session_id}"
    freq_file = TMP / f"claude-freq-{session_id}.json"
    offset_file = TMP / f"claude-offset-{session_id}"

    # Byte offset from last run
    prev_offset = 0
    if offset_file.is_file():
        try:
            prev_offset = int(offset_file.read_text().strip())
        except ValueError:
            pass

    file_size = transcript.stat().st_size
    if file_size <= prev_offset:
        return

    # Read only new bytes
    new_words: list[str] = []
    with open(transcript, "r") as f:
        f.seek(prev_offset)
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") == "user":
                text = extract_text(entry.get("message", {}).get("content", ""))
                new_words.extend(tokenize(text))

    offset_file.write_text(str(file_size))

    if not new_words:
        return

    # Merge with cached frequencies
    freq: Counter = Counter()
    if freq_file.is_file():
        try:
            freq = Counter(json.loads(freq_file.read_text()))
        except (json.JSONDecodeError, ValueError):
            pass
    freq.update(new_words)

    atomic_write(freq_file, json.dumps(freq))

    # Build slug
    topic = "-".join(w for w, _ in freq.most_common(TOP_N))[:MAX_SLUG_LEN]
    if not topic:
        return

    if topic_file.is_file() and topic_file.read_text() == topic:
        return

    atomic_write(topic_file, topic)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # Never disrupt Claude on hook failure
