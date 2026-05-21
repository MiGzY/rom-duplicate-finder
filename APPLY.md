# Applying these fixed files to the GitHub repo

From a clone of the existing repo:

```bash
cd /var/home/migz/Downloads/rom-cleanup-suite
git pull
git checkout -b fix-mame-safe-metadata-orphans
```

Copy the fixed files over the clone. If you extracted the ZIP into `~/Downloads/rom-cleanup-suite-fixed`, run:

```bash
rsync -a --delete --exclude='.git' ~/Downloads/rom-cleanup-suite-fixed/ ./
chmod +x rom_cleanup.sh tests/smoke_test.sh
make check
```

Then commit and push:

```bash
git status
git add .
git commit -m "Fix MAME-safe gamelist cleanup"
git push -u origin fix-mame-safe-metadata-orphans
```

If you only want the script, copy `rom_cleanup.sh` into the existing repo and run:

```bash
chmod +x rom_cleanup.sh
bash -n rom_cleanup.sh
./rom_cleanup.sh --help
```
