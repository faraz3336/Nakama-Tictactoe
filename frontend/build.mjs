import fs from "node:fs/promises";
import path from "node:path";

const root = new URL(".", import.meta.url);
const distDir = new URL("./dist/", root);
const vendorDir = new URL("./dist/vendor/", root);
const isVercelBuild = process.env.VERCEL === "1";
const nakamaServerKey = process.env.NAKAMA_SERVER_KEY || "nakama-server-secret-2026-faraz";
const nakamaUseSSL = process.env.NAKAMA_USE_SSL ?? process.env.NAKAMA_SSL ?? "true";

if (isVercelBuild && !process.env.NAKAMA_SERVER_KEY) {
  throw new Error("NAKAMA_SERVER_KEY is required for Vercel production builds.");
}

const sourceFiles = [
  "index.html",
  "app.js",
  "styles.css",
];

async function main() {
  await fs.rm(distDir, { recursive: true, force: true });
  await fs.mkdir(distDir, { recursive: true });
  await fs.mkdir(vendorDir, { recursive: true });

  for (const file of sourceFiles) {
    let content = await fs.readFile(new URL(`./${file}`, root), "utf8");

    if (file === "app.js") {
      content = content.replace(
        './node_modules/@heroiclabs/nakama-js/dist/nakama-js.esm.mjs',
        "./vendor/nakama-js.esm.mjs",
      );
    }

    await fs.writeFile(new URL(`./${file}`, distDir), content, "utf8");
  }

  const appConfig = `window.__APP_CONFIG__ = ${JSON.stringify({
    nakamaHost: process.env.NAKAMA_HOST || "nakama-tictactoe-khrf.onrender.com",
    nakamaPort: process.env.NAKAMA_PORT || "443",
    nakamaUseSSL: String(nakamaUseSSL).toLowerCase() === "true",
    nakamaServerKey,
  }, null, 2)};\n`;

  await fs.writeFile(new URL("./app-config.js", distDir), appConfig, "utf8");

  const vendorSource = new URL("./node_modules/@heroiclabs/nakama-js/dist/nakama-js.esm.mjs", root);
  const vendorTarget = new URL("./nakama-js.esm.mjs", vendorDir);
  await fs.copyFile(vendorSource, vendorTarget);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
