# Contributing

Run the checks before committing:

```bash
make check
```

Keep cleanup conservative by default:

- do not permanently delete ROM files;
- create backups before editing gamelist files;
- do not move MAME/arcade clone or regional ZIPs from variant cleanup;
- preserve metadata when removing gamelist entries.
