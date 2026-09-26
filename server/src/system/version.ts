/** 比较 x.y.z。返回负数表示 left 比 right 旧。前缀 v 会去掉。 */
export function compareVersions(left: string, right: string): number {
  const a = parts(left);
  const b = parts(right);
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) {
    const diff = (a[i] ?? 0) - (b[i] ?? 0);
    if (diff !== 0) {
      return diff;
    }
  }
  return 0;
}

function parts(version: string): number[] {
  return version
    .trim()
    .replace(/^v/i, '')
    .split('.')
    .map((piece) => {
      const match = /^(\d+)/.exec(piece);
      return match ? Number(match[1]) : 0;
    });
}
