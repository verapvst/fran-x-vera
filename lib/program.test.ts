import { describe, expect, it } from "vitest";
import { INITIAL_EVENTS, OFFICIAL_TOTAL_MINUTES, duration, formatHours, totalOfficialMinutes } from "./program";

describe("programa oficial", () => {
  it("soma exatamente 23h30", () => {
    expect(totalOfficialMinutes(INITIAL_EVENTS)).toBe(OFFICIAL_TOTAL_MINUTES);
    expect(formatHours(totalOfficialMinutes(INITIAL_EVENTS))).toBe("23H30");
  });
  it("trata eventos que passam a meia-noite", () => {
    const e = INITIAL_EVENTS.find((x) => x.id === "e6")!;
    expect(duration(e)).toBe(180);
  });
  it("ignora o work day e o recovery day", () => {
    expect(duration(INITIAL_EVENTS.find((x) => x.id === "e4")!)).toBe(0);
    expect(duration(INITIAL_EVENTS.find((x) => x.id === "e7")!)).toBe(0);
  });
});
