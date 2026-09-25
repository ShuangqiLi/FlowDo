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

  it('rejects unknown themes', async () => {
    const dto = new UpdateMeDto();
    dto.themeKey = 'neon';
    const errors = await validate(dto);
    expect(errors.some((error) => error.property === 'themeKey')).toBe(true);
  });
});
