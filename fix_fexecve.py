#!/usr/bin/env python3
"""Turn fexecve into a one-platform binding: guard the test, register it, fix the sayings."""

# 1) test_unistd: guard the new test body
p = "tests/test_unistd.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"

# the docstring first: the last lines claim both platforms
old_doc = (b"    with, or its own saying that it could not become anything. The asking" + eol +
           b"    is POSIX's own word, and both platforms say it." + eol +
           b'    """' + eol)
new_doc = (b"    with, or its own saying that it could not become anything. The word" + eol +
           b"    is POSIX's own saying, and Linux links it from the library a" + eol +
           b"    just-in-time run looks words up in; Darwin's libSystem keeps no" + eol +
           b"    such symbol to look up." + eol +
           b'    """' + eol)
if old_doc not in s:
    old_doc = old_doc.replace(b"\r\n", b"\n"); eol2 = b"\n"
else:
    eol2 = eol
assert old_doc in s, "docstring not found"
s = s.replace(old_doc, new_doc, 1)

# guard the body: everything after the docstring's closing quotes until
# the end of the function is indented under a comptime if
start = s.find(b'    """' + eol, s.find(b"def test_the_program_said_by_its_own_descriptor_alone"))
# find the end of the docstring
doc_end = s.find(b'    """' + eol, s.find(b"def test_the_program_said_by_its_own_descriptor_alone")) + len(b'    """' + eol)
next_def = s.find(b"def main() raises:", doc_end)
body = s[doc_end:next_def]
lines = body.split(eol)
guarded_lines = []
for line in lines:
    if line == b"":
        guarded_lines.append(b"")
    else:
        guarded_lines.append(b"    " + line)
guarded = eol.join(guarded_lines)
guard_open = (b"    comptime if not CompilationTarget.is_macos():" + eol)
new_body = guard_open + guarded
s = s[:doc_end] + new_body + s[next_def:]
open(p, "wb").write(s)
print("test guarded")

# 2) check-tests: register fexecve
p = "scripts/check-tests.py"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"
o = (b'    "lremovexattr": "the word let go from the link itself; Linux\'s own word, and Darwin answers a different word with the sayings in the other order",' + eol)
if o not in s:
    o = o.replace(b"\r\n", b"\n"); eol = b"\n"
assert o in s, "registration anchor missing"
add = (b'    "fexecve": "the program said by its own descriptor alone; Linux links it from what a just-in-time run looks words up in, and Darwin\'s libSystem keeps no such symbol to look up",' + eol)
s = s.replace(o, o + add, 1)
open(p, "wb").write(s)
print("registered")

# 3) modules.md: bullet + Linux asks 52->53
p = "docs/modules.md"
s = open(p, "rb").read()
old_bullet = (b"- `fexecve` is what `execve` does of a path, said by way of the very file\n"
              b"  itself, with no path at all -- the program is the file `fd` opens, which\n"
              b"  is the way a program that cannot trust the directories on the way says\n"
              b"  itself. What the asking of one that works says is the same as `execveat`\n"
              b"  with `AT_EMPTY_PATH` and an empty saying, spelled without the word that\n"
              b"  carries it.\n")
new_bullet = (b"- `fexecve` is what `execve` does of a path, said by way of the very file\n"
              b"  itself, with no path at all -- the program is the file `fd` opens, which\n"
              b"  is the way a program that cannot trust the directories on the way says\n"
              b"  itself. What the asking of one that works says is the same as `execveat`\n"
              b"  with `AT_EMPTY_PATH` and an empty saying, spelled without the word that\n"
              b"  carries it; Linux links it from what a just-in-time run looks words up\n"
              b"  in, and Darwin's libSystem keeps no such symbol to look up.\n")
assert old_bullet in s
s = s.replace(old_bullet, new_bullet, 1)
s = s.replace(b"Linux asks 52 bindings that Darwin passes over", b"Linux asks 53 bindings that Darwin passes over", 1)
open(p, "wb").write(s)
print("modules.md fixed")

# 4) check-checks fixtures 53/54
p = "scripts/check-checks.py"
s = open(p, "rb").read()
o = b'        "Linux asks 52 bindings that Darwin passes over",\n'
assert s.count(o) == 1
s = s.replace(o, b'        "Linux asks 53 bindings that Darwin passes over",\n', 1)
o2 = b'        "Linux asks 53 bindings that Darwin passes over",\n'
if s.count(o2) == 2:
    first = s.find(o2)
    second = s.find(o2, first + 1)
    s = s[:second] + b'        "Linux asks 54 bindings that Darwin passes over",\n' + s[second+len(o2):]
open(p, "wb").write(s)
print("fixtures 53/54")
