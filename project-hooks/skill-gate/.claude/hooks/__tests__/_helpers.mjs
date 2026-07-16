import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

export const fx = (name) => JSON.parse(readFileSync(join(here, 'fixtures', name), 'utf8'));
