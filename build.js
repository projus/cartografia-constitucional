const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname);
const outDir = path.join(__dirname, 'dist');

if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

// Copy and replace env vars in HTML files
const htmlFiles = fs.readdirSync(srcDir).filter(f => f.endsWith('.html'));

for (const file of htmlFiles) {
  let content = fs.readFileSync(path.join(srcDir, file), 'utf-8');
  content = content.replace(/%%SUPABASE_URL%%/g, process.env.SUPABASE_URL || '');
  content = content.replace(/%%SUPABASE_ANON_KEY%%/g, process.env.SUPABASE_ANON_KEY || '');
  fs.writeFileSync(path.join(outDir, file), content);
}

// Copy JSON data files
const jsonFiles = fs.readdirSync(srcDir).filter(f => f.endsWith('.json') && !f.startsWith('package'));
for (const file of jsonFiles) {
  fs.copyFileSync(path.join(srcDir, file), path.join(outDir, file));
}

console.log(`Build complete: ${htmlFiles.length} HTML + ${jsonFiles.length} JSON -> dist/`);
