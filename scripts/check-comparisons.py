"""Check that every ordering comparison is asked which way it leans.

A comparison answers a sign, and a test that asserts only `!= 0` — or only
`== 0` on strings it knows are the same — is asserting the half of the answer
that survives the two arguments being handed over the other way round. That is
not a hypothetical: `scripts/mutation-probe.py --kind order` found it seven
times in a hundred and twenty swaps, more than any other shape, in
`strncasecmp_l`, `wcsncasecmp_l`, `wcscoll`, `wcscasecmp_l`, `wmemcmp`,
`wcscasecmp` and `wcsncasecmp`. Each was fixed when a sample happened to land
on it, which is the wrong order of events: the shape is not hard to see in the
source, and it does not need a sample to find.

So this asks the whole family at once. Every binding whose symbol ends in
`cmp` or `coll` — `memcmp` and `bcmp` and `strcoll_l` and the wide ones with
them — has to have one assertion that compares the answer with zero, rather
than with `!= 0` or `True`. Two of the family are not orderings and say so
below: the `*xfrm` transforms are not in it by name, and `bcmp` is in it by
name and answers only zero or not.

A comparison bound tomorrow with no sign assertion fails here rather than in
whichever sample comes after it.
"""

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = sorted((ROOT / "tests").glob("*.mojo"))

# A comparison and the same comparison with a locale object: `strcoll` and
# `strcoll_l` lean the same way, and the suffix is the only difference.
ORDERING = re.compile(r"(cmp|coll)(_l)?$")

# Zero or not, and nothing else. BSD's own page says the return is zero if the
# blocks are the same and non-zero otherwise, so both orders answer the same
# non-zero value and a sign assertion would be asserting something the
# standard does not promise.
BINARY_ONLY = {
    "bcmp": "it answers zero or not, and no ordering is promised",
}

# A sign is `< 0` or `> 0` next to the call. `<= 0` is not one of them: it is
# true of the answer in both directions.
SIGN = re.compile(r"[<>]\s*0\b")


def load(name: str):
    """Both scripts need the same walk, and only one of them should hold it."""
    path = ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assertions(text: str):
    """Every `assert_*(` call as the text of that one call."""
    for match in re.finditer(r"assert_\w+\(", text):
        depth = 0
        for index in range(match.end() - 1, len(text)):
            if text[index] == "(":
                depth += 1
            elif text[index] == ")":
                depth -= 1
                if depth == 0:
                    yield match.start(), text[match.start():index + 1]
                    break


def asked(text: str, symbol: str) -> tuple[bool, list[int]]:
    """Whether any assertion holding a call compares its answer with zero."""
    leans, flat = False, []
    for start, block in assertions(text):
        if not re.search(rf"\b{symbol}\(", block):
            continue
        if SIGN.search(block):
            leans = True
        else:
            flat.append(text.count("\n", 0, start) + 1)
    return leans, flat


def main() -> int:
    comparisons = {}
    for _file, _name, symbol, _args, _return, _types in load(
        "check-prototypes"
    ).bindings():
        if ORDERING.search(symbol):
            comparisons[symbol] = True

    probes = {
        path.name: path.read_text()
        for path in TESTS
        if path.name != "test_import_all.mojo"
    }

    unasked, explained, stale = [], [], []
    for symbol in sorted(comparisons):
        leans, flat = False, []
        for text in probes.values():
            found, places = asked(text, symbol)
            leans = leans or found
            flat.extend(places)
        if symbol in BINARY_ONLY:
            if leans:
                stale.append(symbol)
            else:
                explained.append(symbol)
            continue
        if not leans:
            unasked.append((symbol, flat))

    if stale:
        print("these are explained as having no ordering, and one now has one:")
        for symbol in stale:
            print(f"  {symbol}")
        print("take the entry out of BINARY_ONLY, or take the sign out")
        print()

    if unasked:
        print(f"{len(unasked)} comparison(s) are never asked which way they lean:")
        for symbol, flat in unasked:
            where = ", ".join(f"line {line}" for line in flat) or "no call at all"
            print(f"  {symbol}: {where}")
        print()
        print("`!= 0` and `== 0` are the answer whichever order the arguments")
        print("went in. Ask the sign: two strings that differ do not stop")
        print("differing when asked the other way round, and the sign of the")
        print("answer is what a binding handing them over swapped gets wrong")

    if stale or unasked:
        return 1

    print(
        f"{len(comparisons)} comparisons, every one of them asked which way it"
        f" leans"
    )
    for symbol in explained:
        print(f"  and {symbol} is asked only whether: {BINARY_ONLY[symbol]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
