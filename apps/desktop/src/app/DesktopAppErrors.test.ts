import { assert, describe, it } from "@effect/vitest";

import {
  DesktopBackendPortUnavailableError,
  DesktopDevelopmentBackendPortRequiredError,
  shouldUseHostedAppMode,
} from "./DesktopApp.ts";

describe("DesktopApp errors", () => {
  it("preserves unavailable backend port context", () => {
    const error = new DesktopBackendPortUnavailableError({
      startPort: 3_773,
      maxPort: 65_535,
      hosts: ["127.0.0.1", "0.0.0.0", "::"],
    });

    assert.equal(error.startPort, 3_773);
    assert.equal(error.maxPort, 65_535);
    assert.deepEqual(error.hosts, ["127.0.0.1", "0.0.0.0", "::"]);
    assert.equal(
      error.message,
      "No desktop backend port is available on hosts 127.0.0.1, 0.0.0.0, :: between 3773 and 65535.",
    );
  });

  it("reports the required development port", () => {
    const error = new DesktopDevelopmentBackendPortRequiredError();

    assert.equal(error.message, "T3CODE_PORT is required in desktop development.");
  });

  it("uses the hosted app only for a packaged Linux app with the service installed", () => {
    assert.isTrue(
      shouldUseHostedAppMode({
        platform: "linux",
        isPackaged: true,
        isDevelopment: false,
        serviceUnitExists: true,
      }),
    );
    assert.isFalse(
      shouldUseHostedAppMode({
        platform: "linux",
        isPackaged: true,
        isDevelopment: false,
        serviceUnitExists: false,
      }),
    );
    assert.isFalse(
      shouldUseHostedAppMode({
        platform: "darwin",
        isPackaged: true,
        isDevelopment: false,
        serviceUnitExists: true,
      }),
    );
    assert.isFalse(
      shouldUseHostedAppMode({
        platform: "linux",
        isPackaged: false,
        isDevelopment: true,
        serviceUnitExists: true,
      }),
    );
  });
});
