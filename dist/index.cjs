"use strict";
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// src/index.ts
var import_commander = require("commander");
var import_ora = __toESM(require("ora"), 1);
var import_execa = require("execa");
var import_node_machine_id = __toESM(require("node-machine-id"), 1);
var import_supabase_js = require("@supabase/supabase-js");
var import_node_fs = __toESM(require("fs"), 1);
var import_node_os = __toESM(require("os"), 1);
var import_node_path = __toESM(require("path"), 1);
var { machineIdSync } = import_node_machine_id.default;
function appDataDir() {
  const platform = process.platform;
  if (platform === "win32") return import_node_path.default.join(process.env.APPDATA || import_node_path.default.join(import_node_os.default.homedir(), "AppData", "Roaming"), "Crixly");
  if (platform === "darwin") return import_node_path.default.join(import_node_os.default.homedir(), "Library", "Application Support", "Crixly");
  return import_node_path.default.join(process.env.XDG_CONFIG_HOME || import_node_path.default.join(import_node_os.default.homedir(), ".config"), "crixly");
}
function cachePath() {
  return import_node_path.default.join(appDataDir(), "license-cache.json");
}
function readCache() {
  try {
    const p = cachePath();
    if (!import_node_fs.default.existsSync(p)) return null;
    return JSON.parse(import_node_fs.default.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}
function writeCache(cache) {
  import_node_fs.default.mkdirSync(appDataDir(), { recursive: true });
  import_node_fs.default.writeFileSync(cachePath(), JSON.stringify(cache, null, 2), "utf8");
}
function getFingerprint() {
  return machineIdSync({ original: false });
}
async function validateLicenseOnline(key, fingerprint) {
  const url = process.env.CRIXLY_SUPABASE_URL;
  const anonKey = process.env.CRIXLY_SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    throw new Error("Missing CRIXLY_SUPABASE_URL / CRIXLY_SUPABASE_ANON_KEY");
  }
  const supabase = (0, import_supabase_js.createClient)(url, anonKey, { auth: { persistSession: false } });
  const { data, error } = await supabase.rpc("crixly_validate_license", { p_key: key, p_fingerprint: fingerprint });
  if (error) throw new Error(`License validation failed: ${error.message}`);
  if (!data?.ok) {
    const msg = data?.message || "License invalid";
    const err = new Error(msg);
    err.code = "LICENSE_INVALID";
    throw err;
  }
  const nextCheckSeconds = Number(data?.next_check_seconds ?? 3600);
  return { nextCheckSeconds };
}
async function ensureLicensed() {
  const fingerprint = getFingerprint();
  const key = process.env.CRIXLY_LICENSE_KEY || "";
  if (!key) {
    const err = new Error("Missing license key. Set CRIXLY_LICENSE_KEY then retry.");
    err.code = "LICENSE_MISSING";
    throw err;
  }
  const cache = readCache();
  const now = Date.now();
  if (cache && cache.key === key && cache.fingerprint === fingerprint && cache.nextCheckAt > now) {
    return;
  }
  const spinner = (0, import_ora.default)("Validating Crixly license\u2026").start();
  try {
    const { nextCheckSeconds } = await validateLicenseOnline(key, fingerprint);
    spinner.succeed("License valid");
    writeCache({
      key,
      fingerprint,
      lastValidatedAt: now,
      nextCheckAt: now + nextCheckSeconds * 1e3
    });
  } catch (e) {
    spinner.fail(e?.message || "License validation failed");
    throw e;
  }
}
async function runUnderlyingOpenClaw(args) {
  const bin = process.env.CRIXLY_OPENCLAW_BIN || "openclaw";
  const child = (0, import_execa.execa)(bin, args, { stdio: "inherit" });
  await child;
}
var program = new import_commander.Command().name("crixly").description("Crixly CLI").version("0.1.0").enablePositionalOptions();
program.command("onboard").description("Crixly onboarding").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["onboard", ...cmd.args]);
});
program.command("doctor").description("Crixly diagnostics").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["doctor", ...cmd.args]);
});
program.command("configure").description("Crixly configuration").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["configure", ...cmd.args]);
});
program.command("gateway").description("Run the Crixly gateway (licensed)").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["gateway", ...cmd.args]);
});
program.command("status").description("Show Crixly status").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["status", ...cmd.args]);
});
program.command("run").description("Run Crixly (gateway + ui)").allowUnknownOption(true).passThroughOptions().action(async (_, cmd) => {
  await ensureLicensed();
  await runUnderlyingOpenClaw(["gateway", ...cmd.args]);
});
program.command("license:check").description("Validate license now").action(async () => {
  await ensureLicensed();
  console.log("OK");
});
program.parseAsync(process.argv).catch((e) => {
  const msg = e?.message || String(e);
  console.error(msg);
  process.exit(1);
});
