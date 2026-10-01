import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pickApiVersion } from './docker-engine';

describe('pickApiVersion', () => {
  it('follows an older engine instead of asking for a newer API', () => {
    expect(pickApiVersion('1.43')).toBe('1.43');
    expect(pickApiVersion('1.41')).toBe('1.41');
  });

  it('caps at the version FlowDo was written against', () => {
    expect(pickApiVersion('1.47')).toBe('1.44');
    expect(pickApiVersion('2.0')).toBe('1.44');
  });

  it('falls back when the engine does not say', () => {
    expect(pickApiVersion(undefined)).toBe('1.41');
    expect(pickApiVersion('weird')).toBe('1.41');
  });
});

describe('docker calls', () => {
  it('never hardcode an API version in the path', () => {
    const dir = __dirname;
    const offenders = readdirSync(dir)
      .filter((name) => name.endsWith('.ts') && !name.endsWith('.spec.ts'))
      .filter((name) => /['`]\/v\d+\.\d+\//.test(readFileSync(join(dir, name), 'utf8')));
    expect(offenders).toEqual([]);
  });
});
