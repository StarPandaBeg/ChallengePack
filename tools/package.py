"""Create a self-contained TEST BUILD archive without game sources."""
import hashlib
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
dist = root / "dist"
dist.mkdir(exist_ok=True)
target = dist / "ChallengePack-2.0.0-test-win64.zip"
assets = root / "ChallengePack" / "assets" / "protectors.res"
if not assets.is_file():
    raise SystemExit("Build assets first: see README.md")
with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((root / "ChallengePack").rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(root).as_posix())
    for name in ("README.md", "LICENSE", "VALIDATION.md"):
        archive.write(root / name, name)
    for path in sorted((root / ".github").glob("*.png")):
        archive.write(path, path.relative_to(root).as_posix())
digest = hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix(".sha256").write_text(f"{digest}  {target.name}\n", encoding="ascii")
print(target)
print("SHA256:", digest)
