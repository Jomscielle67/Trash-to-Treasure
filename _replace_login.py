import pathlib

base = pathlib.Path('.')
old = "url_for('home')"
new = "url_for('home')"

for f in base.rglob('*'):
    if f.suffix in ('.py', '.html') and f.is_file():
        try:
            text = f.read_text(encoding='utf-8')
        except Exception:
            continue
        if old in text:
            f.write_text(text.replace(old, new), encoding='utf-8')
            print(f'Updated: {f}')

print('Done.')
