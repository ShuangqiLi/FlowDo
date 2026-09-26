import { compareVersions } from './version';

describe('compareVersions', () => {
  it('orders dotted numbers, not text', () => {
    expect(compareVersions('0.9.0', '0.10.0')).toBeLessThan(0);
    expect(compareVersions('0.10.0', '0.9.0')).toBeGreaterThan(0);
    expect(compareVersions('1.0.0', '1.0.0')).toBe(0);
  });

  it('ignores a leading v', () => {
    expect(compareVersions('v0.5.0', '0.5.1')).toBeLessThan(0);
    expect(compareVersions('0.5.0', 'v0.5.0')).toBe(0);
  });
});
