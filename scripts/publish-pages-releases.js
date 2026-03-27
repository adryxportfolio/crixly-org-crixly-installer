import fs from 'node:fs';
import path from 'node:path';

// Copies built artifacts into install/ so Cloudflare Pages deploy publishes them.
// Expected artifacts produced by CI (downloaded/placed manually by CI step):
// - releases/crixly-runtime-dist.tgz
// - releases/crixly-bundled-skills.tgz

const releasesDir = path.resolve('releases');
const installReleasesDir = path.resolve('install', 'releases');

fs.mkdirSync(installReleasesDir, { recursive: true });

for (const name of ['crixly-runtime-dist.tgz', 'crixly-bundled-skills.tgz']) {
  const src = path.join(releasesDir, name);
  if (!fs.existsSync(src)) {
    console.error(`Missing ${src}. Did you run build-runtime workflow and download artifacts?`);
    process.exit(2);
  }
  const dst = path.join(installReleasesDir, name);
  fs.copyFileSync(src, dst);
  console.log(`Copied ${src} -> ${dst}`);
}
