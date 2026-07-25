import { describe, expect, it } from "@effect/vitest";
import { getProviderOptionDescriptors } from "@t3tools/shared/model";

import {
  claudeModelsFromSettings,
  getClaudeModelCapabilities,
  normalizeClaudeCliEffort,
} from "./ClaudeProvider.ts";

function effortOptions(model: string): ReadonlyArray<string> {
  const descriptor = getProviderOptionDescriptors({
    caps: getClaudeModelCapabilities(model),
  }).find((candidate) => candidate.id === "effort");
  return descriptor?.type === "select" ? descriptor.options.map((option) => option.id) : [];
}

describe("Claude OpenAI gateway models", () => {
  it("exposes model-specific effort levels and keeps Sol low by default", () => {
    expect(effortOptions("gpt-5.6-sol")).toEqual(["low", "medium", "high", "xhigh", "max"]);
    expect(effortOptions("gpt-5.6-luna")).toEqual(["low", "medium", "high", "xhigh", "max"]);
    expect(effortOptions("gpt-5.4-mini")).toEqual(["low", "medium", "high", "xhigh"]);

    const solEffort = getProviderOptionDescriptors({
      caps: getClaudeModelCapabilities("gpt-5.6-sol"),
    }).find((candidate) => candidate.id === "effort");
    expect(solEffort?.currentValue).toBe("low");
  });

  it("preserves xhigh when the Claude harness targets an OpenAI gateway model", () => {
    expect(normalizeClaudeCliEffort("xhigh", "gpt-5.6-sol")).toBe("xhigh");
    expect(normalizeClaudeCliEffort("xhigh", "gpt-5.4-mini")).toBe("xhigh");
  });

  it("enriches configured gateway models without enabling unconfigured ones", () => {
    const models = claudeModelsFromSettings([], ["gpt-5.6-sol", "gpt-5.4-mini", "private-model"]);

    expect(models.map((model) => model.slug)).toEqual([
      "gpt-5.6-sol",
      "gpt-5.4-mini",
      "private-model",
    ]);
    expect(models[0]).toMatchObject({
      name: "GPT 5.6 Sol",
      isCustom: true,
      isDefault: true,
    });
    expect(models[2]?.capabilities?.optionDescriptors).toEqual([]);
  });
});
