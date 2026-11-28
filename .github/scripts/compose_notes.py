"""compose_notes.py <tag>: print the What to Test notes for a build-<N> tag.

The tag's own body comes first, as written. Then, for players who skip builds,
the "New" lines of every earlier build in the same major version, newest first
(0.x builds all count; 1.0 starts over). Their "Please test" lists are dropped,
since they're stale. TestFlight allows 4000 characters, so the oldest builds
are left out when it gets too long.

A tag body looks like:

    New:
    - ...

    Please test:
    - ...
"""
import re
import subprocess
import sys

LIMIT = 4000
MORE = "Older builds: see What's New in Settings."


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def version_at(ref):
    m = re.search(r'^\s*MARKETING_VERSION:\s*"?([0-9.]+)"?', git("show", f"{ref}:project.yml"), re.M)
    return m.group(1) if m else "?"


def body(tag):
    return git("tag", "-l", "--format=%(contents:body)", tag).strip()


def new_lines(text):
    """The lines of a body's "New" section, without its header."""
    out = []
    for line in text.splitlines():
        if re.match(r"\s*please test\b", line, re.I):
            break
        if re.match(r"\s*new\b.*:\s*$", line, re.I) and not out:
            continue
        out.append(line)
    return "\n".join(out).strip()


def main():
    tag = sys.argv[1]
    number = int(tag.removeprefix("build-"))
    major = version_at(tag).split(".")[0]
    notes = body(tag)

    earlier = []
    tags = [t for t in git("tag", "-l", "build-*").split() if t.removeprefix("build-").isdigit()]
    for t in sorted(tags, key=lambda t: -int(t.removeprefix("build-"))):
        n = int(t.removeprefix("build-"))
        if n >= number:
            continue
        version = version_at(t)
        if version.split(".")[0] != major:
            break
        lines = new_lines(body(t))
        if lines:
            earlier.append(f"Build {n} ({version}):\n{lines}")

    text = notes
    if earlier:
        text += f"\n\nEarlier builds of {major}.x:"
        for i, block in enumerate(earlier):
            rest_needs = len("\n\n" + MORE) if i < len(earlier) - 1 else 0
            if len(text) + 2 + len(block) + rest_needs > LIMIT:
                if len(text) + 2 + len(MORE) <= LIMIT:
                    text += "\n\n" + MORE
                break
            text += "\n\n" + block
    print(text[:LIMIT])


main()
