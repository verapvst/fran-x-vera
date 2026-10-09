import { describe, expect, it } from "vitest";
import { teamScore } from "./score";

describe("teamScore", () => {
  it("divide pelos presentes", () => expect(teamScore(300, 6)).toBe(50));
  it("equipas maiores não ganham só por terem mais gente", () => {
    expect(teamScore(400, 8)).toBe(teamScore(300, 6));
  });
  it("sem presentes dá 0", () => expect(teamScore(100, 0)).toBe(0));
});
