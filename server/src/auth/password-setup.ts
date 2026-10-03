export function needsPasswordSetup(instance: {
  passwordHash: string;
  mustChangePassword: boolean;
} | null): boolean {
  return (
    instance == null ||
    instance.mustChangePassword ||
    instance.passwordHash.length === 0
  );
}
