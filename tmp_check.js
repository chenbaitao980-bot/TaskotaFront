const fs = require('fs');
const dir = 'E:/claude/project2/taskora-website/src/pages/admin/';
const files = ['members.astro', 'payment.astro', 'downloads.astro', 'layout.astro'];
files.forEach(f => {
  const t = fs.readFileSync(dir + f, 'utf8');
  const titles = t.match(/title="([^"]+)"/g) || [];
  const hints = t.match(/<p class="admin-hint">([^<]+)</g) || [];
  console.log('=== ' + f + ' ===');
  titles.forEach(x => console.log('  title: ' + x.replace('title="', '').replace('"', '')));
  hints.forEach(x => console.log('  hint: ' + x.replace('<p class="admin-hint">', '')));
  console.log('---');
});
