import re, os, glob

pkg_import = "import 'package:smart_assistant/core/utils/snackbar_helper.dart';"

files = glob.glob('lib/**/*.dart', recursive=True)

for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'showSnackBar' not in content or 'snackbar_helper' in fpath:
        continue
    
    original = content
    
    # Pattern: multi-line ScaffoldMessenger.of(\n  context,\n).showSnackBar(const? SnackBar(content: Text('...')));
    content = re.sub(
        r"ScaffoldMessenger\.of\(\s*\n\s*context,?\s*\n\s*\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('([^']*)'\)\)\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern: single-line ScaffoldMessenger.of(context).showSnackBar(const? SnackBar(content: Text('...')));
    content = re.sub(
        r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('([^']*)'\)\)\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern: chained .showSnackBar on next line
    content = re.sub(
        r"ScaffoldMessenger\.of\(context\)\s*\n\s*\.showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('([^']*)'\)\)\s*\);",
        r"showAppSnackBar(context, '\1');",
        content
    )
    
    # Pattern: ..showSnackBar (cascade) - register_page special case
    content = re.sub(
        r"\.\.\s*showSnackBar\(\s*(?:const\s+)?SnackBar\(content:\s*Text\('([^']*)'\)\)\s*\)",
        r"..showSnackBar(SnackBar(content: Text('\1')))",
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
        
        remaining = content.count('showSnackBar')
        converted = content.count('showAppSnackBar') - 1  # minus import
        print(f'Updated: {fpath} (converted: {converted}, remaining showSnackBar: {remaining})')
