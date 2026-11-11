"""Fetch one pinned ComfyUI commit without needing Git installed (uses pygit2).

usage: fetch_comfyui.py <repo-url> <tag> <commit-sha> <dest>

Fetches only <tag> (depth 1), checks that it points at <commit-sha>, writes the
files to <dest> and removes the .git folder so the result matches a ZIP install.
The commit SHA is the pin: Git object ids are content hashes, so if the commit
matches, every file in its tree matches what the pins.json author reviewed.
"""
import os
import shutil
import stat
import sys

import pygit2


def _rm_readonly(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


def main():
    url, tag, commit, dest = sys.argv[1:5]
    if os.path.exists(dest):
        sys.exit(f"destination already exists: {dest}")
    repo = pygit2.init_repository(dest)
    try:
        remote = repo.remotes.create_anonymous(url)
        remote.fetch([f"+refs/tags/{tag}:refs/tags/{tag}"], depth=1)
        got = str(repo.revparse_single(f"refs/tags/{tag}").peel(pygit2.Commit).id)
        if got != commit:
            sys.exit(f"tag {tag} points at {got}, expected {commit}: refusing to install")
        repo.checkout_tree(repo[got].tree, strategy=pygit2.GIT_CHECKOUT_FORCE)
    except BaseException:
        repo.free()
        shutil.rmtree(dest, onerror=_rm_readonly)
        raise
    repo.free()
    shutil.rmtree(os.path.join(dest, ".git"), onerror=_rm_readonly)
    if not os.path.isfile(os.path.join(dest, "main.py")):
        sys.exit("fetched tree has no main.py")
    print(f"ComfyUI {tag} ({commit[:12]}) OK")


if __name__ == "__main__":
    main()
