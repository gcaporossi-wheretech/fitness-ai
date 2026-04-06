/**
 * Tests for the API client module.
 */
import { ApiError } from "@/lib/api";

describe("ApiError", () => {
  it("should create an error with statusCode and detail", () => {
    const error = new ApiError(404, "Not found");
    expect(error.statusCode).toBe(404);
    expect(error.detail).toBe("Not found");
    expect(error.message).toBe("Not found");
    expect(error.name).toBe("ApiError");
  });

  it("should be an instance of Error", () => {
    const error = new ApiError(500, "Internal server error");
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(ApiError);
  });
});
