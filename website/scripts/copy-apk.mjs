#!/usr/bin/env node
/**
 * Copies the Flutter release APK into public/ so `npm run build` serves it at
 * /fundmf-release.apk for the mobile "Download APK" button.
 *
 * Usage: npm run copy-apk [-- <path-to-apk>]
 * Default source (sibling Flutter project):
 *   ../build/app/outputs/flutter-apk/app-release.apk
 */
import { copyFile, mkdir, stat } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

const source = resolve(
  process.argv[2] ?? resolve(root, '..', 'build/app/outputs/flutter-apk/app-release.apk'),
);
const destination = resolve(root, 'public/fundmf-release.apk');

try {
  await stat(source);
} catch {
  console.error(`APK not found at ${source}`);
  console.error(
    'Build it first: cd .. && flutter build apk --release, or pass a path: npm run copy-apk -- /path/to/app-release.apk',
  );
  process.exit(1);
}

await mkdir(dirname(destination), { recursive: true });
await copyFile(source, destination);

const { size } = await stat(destination);
console.log(
  `Copied ${source} -> ${destination} (${(size / 1024 / 1024).toFixed(1)} MB)`,
);
console.log('It is gitignored; it ships with the hosting deploy, not the repo.');
