import re, os, glob

pkg_import = "import 'package:smart_assistant/core/utils/snackbar_helper.dart';"

files = glob.glob('lib/**/*.dart', recursive=True)

for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'showSnackBar' not in content or 'snackbar_helper' in fpath:
        continue
    
    # Skip if already fully converted
    if 'ScaffoldMessenger' not in content:
        continue
    
    original = content
    
    # Pattern A: single-line with possible interpolation
    # ScaffoldMessenger.of(context).showSnackBar(\n?  const? SnackBar(content: Text('...')),?\n?);
    content = re.sub(
        r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*\n?\s*(?:const\s+)?SnackBar\(content:\s*Text\('((?:[^'\\]|\\.)*)'\)\s*\),?\s*\n?\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern B: multi-line ScaffoldMessenger.of(\n  context,\n  ).showSnackBar(...)
    content = re.sub(
        r"ScaffoldMessenger\.of\(\s*\n\s*context,?\s*\n\s*\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('((?:[^'\\]|\\.)*)'\)\s*\),?\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern C: chained on next line
    content = re.sub(
        r"ScaffoldMessenger\.of\(context\)\s*\n\s*\.showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('((?:[^'\\]|\\.)*)'\)\s*\),?\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern D: cascade ..clearSnackBars() ..showSnackBar(...) 
    content = re.sub(
        r"ScaffoldMessenger\.of\(context\)\s*\n?\s*\.\.\s*clearSnackBars\(\)\s*\n?\s*\.\.\s*showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('((?:[^'\\]|\\.)*)'\)\)\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    if content != original:
        # Add import if not already there
        if pkg_import not in content and 'showAppSnackBar' in content:
            lines = content.split('\n')
            last_import = -1
            for i, line in enumerate(lines):
                if line.strip().startswith('import '):
                    last_import = i
            if last_import >= 0:
                lines.insert(last_import + 1, pkg_import)
                content = '\n'.join(lines)
        
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        remaining = len(re.findall(r'ScaffoldMessenger.*showSnackBar', content))
        converted = content.count('showAppSnackBar') - (1 if pkg_import in content else 0)
        print(f'Updated: {fpath} (showAppSnackBar: {converted}, remaining ScaffoldMessenger: {remaining})')

# Report files still with showSnackBar
print("\n--- Files still with ScaffoldMessenger.showSnackBar ---")
for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    if 'snackbar_helper' in fpath:
        continue
    lines_with = [(i+1, l.strip()) for i, l in enumerate(content.split('\n')) if 'showSnackBar' in l and 'ScaffoldMessenger' in content]
    if lines_with:
        for ln, line in lines_with:
            print(f'{fpath}:{ln}: {line[:100]}')
