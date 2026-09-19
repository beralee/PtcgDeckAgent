import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';

// Public, immutable package download; no operator credentials or private APIs.
const directory = resolve(process.argv[2] || '../../.tmp/web-strategy-start/fixture');
const releaseId = process.argv[3] || 'release-24dc3d5ee410eb8546bbdfc74d991230aed9dafb';
if (!/^release-[a-f0-9]+$/.test(releaseId)) throw new Error('Invalid release ID');
const origin = 'https://api.ptcg.skillserver.cn';
async function get(path) {
  const response = await fetch(origin + path);
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response;
}
const profile = await (await get(`/v1/ladder/releases/${releaseId}/profile`)).json();
const board = await (await get('/v1/ladder/leaderboard')).json();
board.items = board.items.filter(item => item.release_id === releaseId);
if (board.items.length !== 1 || !profile.release.download_available) throw new Error('Release is not available on the public ladder');
const archive = Buffer.from(await (await get(`/v1/ladder/releases/${releaseId}/package`)).arrayBuffer());
if (createHash('sha256').update(archive).digest('hex').toUpperCase() !== profile.release.archive_sha256) throw new Error('Package hash mismatch');
await mkdir(directory, { recursive: true });
await writeFile(join(directory, 'leaderboard.json'), JSON.stringify(board));
await writeFile(join(directory, 'profile.json'), JSON.stringify(profile));
await writeFile(join(directory, 'marnie.ptcgai'), archive);
console.log(`Pinned ${profile.release.display_name} ${profile.release.package_version} to ${directory}`);
