import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function clearExtension(pi: ExtensionAPI) {
  pi.registerCommand("clear", {
    description: "Clear context by starting a fresh session",
    handler: async (_args, ctx) => {
      await ctx.waitForIdle();

      const result = await ctx.newSession({
        withSession: async (replacementCtx) => {
          replacementCtx.ui.notify("Context cleared.", "info");
        },
      });

      if (result.cancelled) {
        ctx.ui.notify("Clear cancelled.", "info");
      }
    },
  });
}
