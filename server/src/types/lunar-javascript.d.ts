declare module 'lunar-javascript' {
  export class Solar {
    static fromYmd(year: number, month: number, day: number): Solar;
    getLunar(): Lunar;
  }

  export class Lunar {
    static fromYmd(year: number, month: number, day: number): Lunar;
    getSolar(): SolarDate;
    getYear(): number;
    getMonth(): number;
    getDay(): number;
    getMonthInChinese(): string;
    getDayInChinese(): string;
  }

  export class SolarDate {
    getYear(): number;
    getMonth(): number;
    getDay(): number;
  }

  export class LunarYear {
    static fromYear(year: number): LunarYear;
    getMonths(): LunarMonth[];
  }

  export class LunarMonth {
    getYear(): number;
    getMonth(): number;
    getDayCount(): number;
  }
}
