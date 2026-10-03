import { needsPasswordSetup } from './password-setup';

describe('needsPasswordSetup', () => {
  it('is true before a password is chosen', () => {
    expect(needsPasswordSetup(null)).toBe(true);
    expect(
      needsPasswordSetup({ passwordHash: '', mustChangePassword: true }),
    ).toBe(true);
    expect(
      needsPasswordSetup({
        passwordHash: 'old-hash',
        mustChangePassword: true,
      }),
    ).toBe(true);
  });

  it('is false once a password is set', () => {
    expect(
      needsPasswordSetup({
        passwordHash: 'hash',
        mustChangePassword: false,
      }),
    ).toBe(false);
  });
});
