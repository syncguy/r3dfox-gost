from pathlib import Path
p = Path('build/apply-gost-stage2-next.py')
s = p.read_text(encoding='utf-8')
old = "close_anchor = '    msspi_close(secret->msspi);\\n'"
new = "close_anchor = '    (void)msspi_close(secret->msspi);\\n'"
if old not in s:
    raise SystemExit('old close anchor not found in patcher')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
