import { describe, expect, test } from "vitest";
import { registerSchema } from "../../src/schemas/auth.schemas.js";

describe("registerSchema", () => {
  test("accepts valid registration details", () => {
    const result = registerSchema.safeParse({
      first_name: "Karl",
      last_name: "Kirby",
      email: "karl@example.com",
      password: "password123",
    });

    expect(result.success).toBe(true);
  });

  test.each([
    [
      "rejects an empty first name",
      {
        first_name: "",
        last_name: "Kirby",
        email: "karl@example.com",
        password: "password123",
      },
    ],
    [
      "rejects an empty last name",
      {
        first_name: "Karl",
        last_name: "",
        email: "karl@example.com",
        password: "password123",
      },
    ],
    [
      "rejects an invalid email",
      {
        first_name: "Karl",
        last_name: "Kirby",
        email: "invalid-email",
        password: "password123",
      },
    ],
    [
      "rejects a short password",
      {
        first_name: "Karl",
        last_name: "Kirby",
        email: "karl@example.com",
        password: "123",
      },
    ],
  ])("%s", (_description, input) => {
    const result = registerSchema.safeParse(input);

    expect(result.success).toBe(false);
  });
});
