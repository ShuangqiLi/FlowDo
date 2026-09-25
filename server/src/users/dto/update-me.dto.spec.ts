import { validate } from 'class-validator';
import { UpdateMeDto } from './update-me.dto';

describe('UpdateMeDto themeKey', () => {
  it.each(['mint', 'hazeBlue', 'warmOrange', 'lightPurple'])(
    'accepts %s',
    async (themeKey) => {
      const dto = new UpdateMeDto();
      dto.themeKey = themeKey;
      await expect(validate(dto)).resolves.toHaveLength(0);
    },
  );

  it('accepts 0 as keep archived forever', async () => {
    const dto = new UpdateMeDto();
    dto.deleteArchivedAfterDays = 0;
    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects a negative purge delay', async () => {
    const dto = new UpdateMeDto();
    dto.deleteArchivedAfterDays = -1;
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'deleteArchivedAfterDays')).toBe(
      true,
    );
  });
});
