#!/usr/bin/env python3
from __future__ import annotations

import argparse
import heapq
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PhraseEntry:
    phrase: str
    author: str = ""

    def as_line(self) -> str:
        phrase = self.phrase.strip()
        author = self.author.strip()
        return f"{phrase}||{author}" if author else phrase


SHERLOCK_HOLMES_QUOTES: tuple[PhraseEntry, ...] = (
    PhraseEntry("Это элементарно.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Факты прежде всего.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Сначала факты, потом выводы.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Вы видите, но вы не наблюдаете.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Данные! Мне нужны данные.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Наблюдение — первый шаг к разгадке.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Логика без наблюдательности слепа.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Внимание к мелочам раскрывает большие тайны.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Нет ничего более обманчивого, чем очевидный факт.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Когда исключишь невозможное, оставшееся — истина.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry("Когда исключаешь невозможное, остаётся истина — какой бы невероятной она ни казалась.", "ШЕРЛОК ХОЛМС"),
    PhraseEntry(
        "Ошибочно строить теории без фактов: вы незаметно начнёте подгонять факты под выводы, игнорируя всё, что им противоречит.",
        "ШЕРЛОК ХОЛМС",
    ),
)


def parse_phrase_entries(text: str) -> list[PhraseEntry]:
    entries: list[PhraseEntry] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if "||" in line:
            phrase, author = line.split("||", 1)
            phrase = phrase.strip()
            author = author.strip()
        else:
            phrase = line
            author = ""

        if not phrase:
            continue

        entries.append(PhraseEntry(phrase=phrase, author=author))
    return entries


def phrase_letter_count(text: str) -> int:
    return sum(1 for ch in text if ch.isalpha())


def dedupe(entries: list[PhraseEntry]) -> list[PhraseEntry]:
    seen: set[tuple[str, str]] = set()
    result: list[PhraseEntry] = []
    for entry in entries:
        key = (entry.phrase.strip(), entry.author.strip())
        if key in seen:
            continue
        seen.add(key)
        result.append(entry)
    return result


def arrange_length_group(entries: list[PhraseEntry], last_author: str) -> tuple[list[PhraseEntry], str]:
    entries_by_author: dict[str, list[PhraseEntry]] = defaultdict(list)
    for entry in sorted(entries, key=lambda item: (item.author, item.phrase)):
        entries_by_author[entry.author].append(entry)

    heap: list[tuple[int, str]] = []
    for author, items in entries_by_author.items():
        heapq.heappush(heap, (-len(items), author))

    arranged: list[PhraseEntry] = []
    previous_author = last_author

    while heap:
        count1, author1 = heapq.heappop(heap)

        if previous_author and author1 and author1 == previous_author and heap:
            count2, author2 = heapq.heappop(heap)
            next_entry = entries_by_author[author2].pop(0)
            arranged.append(next_entry)
            previous_author = next_entry.author

            if entries_by_author[author2]:
                heapq.heappush(heap, (-len(entries_by_author[author2]), author2))
            heapq.heappush(heap, (count1, author1))
            continue

        next_entry = entries_by_author[author1].pop(0)
        arranged.append(next_entry)
        previous_author = next_entry.author
        if entries_by_author[author1]:
            heapq.heappush(heap, (-len(entries_by_author[author1]), author1))

    return arranged, previous_author


def reorder_by_length(entries: list[PhraseEntry], avoid_adjacent_authors: bool) -> list[PhraseEntry]:
    entries = dedupe(entries)

    by_length: dict[int, list[PhraseEntry]] = defaultdict(list)
    for entry in entries:
        by_length[phrase_letter_count(entry.phrase)].append(entry)

    ordered: list[PhraseEntry] = []
    last_author = ""
    for length in sorted(by_length):
        group = by_length[length]
        if avoid_adjacent_authors:
            arranged, last_author = arrange_length_group(group, last_author)
            ordered.extend(arranged)
        else:
            group_sorted = sorted(group, key=lambda item: (item.author, item.phrase))
            ordered.extend(group_sorted)
            if group_sorted:
                last_author = group_sorted[-1].author

    return ordered


def write_entries(path: Path, entries: list[PhraseEntry]) -> None:
    content = "\n".join(entry.as_line() for entry in entries).strip() + "\n"
    path.write_text(content, encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Sorts phrases by length (short → long) and optionally avoids consecutive identical authors."
    )
    parser.add_argument("--input", default="Cryptogram/phrases.txt", help="Input .txt file in PHRASE[||AUTHOR] format.")
    parser.add_argument("--output", default="", help="Output file path (defaults to in-place update).")
    parser.add_argument(
        "--extra",
        action="append",
        default=[],
        help="Extra phrase files to append before sorting (same PHRASE[||AUTHOR] format). Can be used multiple times.",
    )
    parser.add_argument("--add-sherlock", action="store_true", help="Append Sherlock Holmes phrases before sorting.")
    parser.add_argument(
        "--allow-adjacent-authors",
        action="store_true",
        help="Do not try to separate identical adjacent authors (still sorts by length).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print result to stdout instead of writing files.")

    args = parser.parse_args(argv)

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 2

    entries = parse_phrase_entries(input_path.read_text(encoding="utf-8"))
    for extra_path in args.extra:
        extra_file = Path(extra_path)
        if not extra_file.exists():
            print(f"Extra file not found: {extra_file}", file=sys.stderr)
            return 2
        entries.extend(parse_phrase_entries(extra_file.read_text(encoding="utf-8")))

    if args.add_sherlock:
        entries.extend(SHERLOCK_HOLMES_QUOTES)

    ordered = reorder_by_length(entries, avoid_adjacent_authors=not args.allow_adjacent_authors)
    output_path = Path(args.output) if args.output else input_path

    if args.dry_run:
        sys.stdout.write("\n".join(entry.as_line() for entry in ordered).strip() + "\n")
        return 0

    write_entries(output_path, ordered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
