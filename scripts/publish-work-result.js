#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const DEFAULT_REPO_ROOT = path.resolve(__dirname, "..");
const FEED_RELATIVE_PATH = "public/data/work-feed.json";
const STATE_RELATIVE_PATH = ".cache/work-feed-hook/state.json";

const options = parseArgs(process.argv.slice(2));
const repoRoot = path.resolve(options.repo || DEFAULT_REPO_ROOT);
const feedPath = path.join(repoRoot, FEED_RELATIVE_PATH);
const statePath = path.join(repoRoot, STATE_RELATIVE_PATH);

const skipExact = new Set([
  FEED_RELATIVE_PATH,
  STATE_RELATIVE_PATH,
  ".DS_Store",
]);

const skipPrefixes = [
  ".git/",
  ".cache/",
  "node_modules/",
  "dist/",
  "build/",
];

const privatePrefixes = [
  "internal-notes/",
  "raw/references/",
];

const textExtensions = new Set([
  ".css",
  ".html",
  ".js",
  ".json",
  ".md",
  ".mjs",
  ".svg",
  ".txt",
  ".yml",
  ".yaml",
]);

main();

function main() {
  const hookInput = readHookInput(options.hookInput);
  const eventCwd = normalizePath(
    hookInput.cwd ||
      hookInput.current_working_dir ||
      hookInput.working_directory ||
      process.env.PWD ||
      process.cwd(),
  );

  if (options.requireCwdMatch && !isInsidePath(eventCwd, repoRoot)) {
    finish({ action: "skip", reason: "outside-repository" });
    return;
  }

  const changes = getChanges();
  const publishableChanges = changes.filter(isPublishableChange);
  const visibleFiles = publishableChanges
    .filter((change) => !isPrivatePath(change.path))
    .map((change) => change.path);

  if (publishableChanges.length === 0 && !options.force) {
    finish({ action: "skip", reason: "no-publishable-changes" });
    return;
  }

  const quality = evaluateQuality(publishableChanges);
  if (!quality.ok && !options.force) {
    finish({ action: "skip", reason: quality.reason, details: quality.details });
    return;
  }

  const score = scoreChanges(publishableChanges);
  const decision = decidePublish(score, publishableChanges);

  if (!decision.publish && !options.force) {
    finish({
      action: "skip",
      reason: "below-publish-threshold",
      score,
      reasons: decision.reasons,
    });
    return;
  }

  const fingerprint = createFingerprint(publishableChanges);
  const state = readJson(statePath, {});
  const feed = readJson(feedPath, []);

  if (!Array.isArray(feed)) {
    throw new Error(`${FEED_RELATIVE_PATH} must contain a JSON array.`);
  }

  if (!options.force) {
    if (state.lastFingerprint === fingerprint) {
      finish({ action: "skip", reason: "duplicate-fingerprint" });
      return;
    }

    if (feed.some((post) => post && post.fingerprint === fingerprint)) {
      writeState({ lastFingerprint: fingerprint, lastDecisionAt: new Date().toISOString() });
      finish({ action: "skip", reason: "already-published" });
      return;
    }
  }

  const post = buildPost({
    fingerprint,
    hookInput,
    publishableChanges,
    quality,
    score,
    visibleFiles,
  });

  if (options.dryRun) {
    finish({ action: "dry-run", post });
    return;
  }

  const nextFeed = [post, ...feed].slice(0, options.maxPosts);
  writeJson(feedPath, nextFeed);
  writeState({
    lastFingerprint: fingerprint,
    lastDecisionAt: new Date().toISOString(),
    lastPostId: post.id,
  });

  finish({ action: "published", id: post.id, score, files: visibleFiles });
}

function parseArgs(args) {
  const parsed = {
    dryRun: false,
    force: false,
    hookInput: "",
    maxPosts: 40,
    quiet: false,
    repo: "",
    requireCwdMatch: false,
    summary: "",
    title: "",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (arg === "--dry-run") parsed.dryRun = true;
    else if (arg === "--force") parsed.force = true;
    else if (arg === "--quiet") parsed.quiet = true;
    else if (arg === "--require-cwd-match") parsed.requireCwdMatch = true;
    else if (arg === "--hook-input") parsed.hookInput = String(args[(index += 1)] || "");
    else if (arg === "--max-posts") parsed.maxPosts = Number(args[(index += 1)] || 40);
    else if (arg === "--repo") parsed.repo = String(args[(index += 1)] || "");
    else if (arg === "--summary") parsed.summary = String(args[(index += 1)] || "");
    else if (arg === "--title") parsed.title = String(args[(index += 1)] || "");
  }

  if (!Number.isFinite(parsed.maxPosts) || parsed.maxPosts < 1) {
    parsed.maxPosts = 40;
  }

  return parsed;
}

function readHookInput(inputPath) {
  if (!inputPath) return {};

  try {
    const raw = fs.readFileSync(inputPath, "utf8").trim();
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function getChanges() {
  const output = git(["status", "--porcelain=v1", "--untracked-files=all"]);

  return output
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const status = line.slice(0, 2);
      const rawPath = line.slice(3);
      const filePath = rawPath.includes(" -> ")
        ? rawPath.split(" -> ").pop()
        : rawPath;

      return {
        path: normalizeGitPath(filePath),
        status,
      };
    });
}

function isPublishableChange(change) {
  if (!change || !change.path) return false;
  if (skipExact.has(change.path)) return false;
  if (skipPrefixes.some((prefix) => change.path.startsWith(prefix))) return false;
  if (change.path.endsWith(".log") || change.path.endsWith(".tmp")) return false;
  return true;
}

function isPrivatePath(filePath) {
  return privatePrefixes.some((prefix) => filePath.startsWith(prefix));
}

function evaluateQuality(changes) {
  const diffCheck = runGitCheck(["diff", "--check"]);

  if (!diffCheck.ok) {
    return {
      ok: false,
      reason: "diff-check-failed",
      details: diffCheck.output,
    };
  }

  const conflictFile = changes.find((change) => hasConflictMarkers(change.path));

  if (conflictFile) {
    return {
      ok: false,
      reason: "conflict-markers-found",
      details: conflictFile.path,
    };
  }

  return { ok: true, reason: "quality-gates-passed" };
}

function scoreChanges(changes) {
  let score = 0;

  for (const change of changes) {
    const filePath = change.path;

    if (filePath.startsWith("public/assets/")) score += 5;
    else if (filePath.startsWith("raw/generated/")) score += 5;
    else if (filePath.startsWith("public/")) score += 4;
    else if (filePath.startsWith("prompts/")) score += 3;
    else if (filePath.startsWith("experiments/")) score += 3;
    else if (filePath === "README.md" || filePath === "public/README.md") score += 2;
    else if (filePath.startsWith("scripts/")) score += 2;
    else if (filePath.startsWith(".github/workflows/")) score += 2;
    else if (isPrivatePath(filePath)) score += 0;
    else score += 1;

    if (change.status.includes("D")) score -= 1;
  }

  return Math.max(0, score);
}

function decidePublish(score, changes) {
  const reasons = [];
  const hasPublicOutput = changes.some((change) => change.path.startsWith("public/"));
  const hasGeneratedArt = changes.some((change) => change.path.startsWith("raw/generated/"));
  const hasExperiment = changes.some((change) => change.path.startsWith("experiments/"));
  const hasAutomation = changes.some((change) => change.path.startsWith("scripts/"));

  if (hasPublicOutput) reasons.push("public-output");
  if (hasGeneratedArt) reasons.push("generated-art");
  if (hasExperiment) reasons.push("experiment");
  if (hasAutomation) reasons.push("automation");

  return {
    publish: score >= 4 && reasons.length > 0,
    reasons,
  };
}

function createFingerprint(changes) {
  const hash = crypto.createHash("sha256");
  hash.update(git(["rev-parse", "--verify", "HEAD"], { allowFailure: true }).trim());

  for (const change of [...changes].sort((a, b) => a.path.localeCompare(b.path))) {
    hash.update("\n");
    hash.update(change.status);
    hash.update(" ");
    hash.update(change.path);
    hash.update(" ");
    hash.update(hashFile(change.path));
  }

  return hash.digest("hex");
}

function buildPost({ fingerprint, hookInput, publishableChanges, quality, score, visibleFiles }) {
  const now = new Date();
  const dominant = getDominantCategory(publishableChanges);
  const title = options.title || getDefaultTitle(dominant, publishableChanges);
  const summary = options.summary || getDefaultSummary(visibleFiles, hookInput);
  const href = getDefaultHref(visibleFiles);
  const scoreLabel = score >= 10 ? "Ready" : "Review";

  return {
    id: `work-${formatTimestamp(now)}-${fingerprint.slice(0, 8)}`,
    createdAt: now.toISOString(),
    title,
    summary,
    category: dominant.label,
    handle: "@codex-hook",
    status: scoreLabel,
    href,
    files: visibleFiles.slice(0, 8),
    score,
    reasons: decidePublish(score, publishableChanges).reasons,
    quality: quality.reason,
    fingerprint,
  };
}

function getDominantCategory(changes) {
  const counts = new Map();

  for (const change of changes) {
    const category = categorize(change.path);
    counts.set(category.key, {
      ...category,
      count: (counts.get(category.key)?.count || 0) + 1,
    });
  }

  return [...counts.values()].sort((a, b) => b.count - a.count)[0] || {
    key: "work",
    label: "작업 결과",
  };
}

function categorize(filePath) {
  if (filePath.startsWith("public/assets/")) return { key: "asset", label: "Asset" };
  if (filePath.startsWith("raw/generated/")) return { key: "generated", label: "Generated art" };
  if (filePath.startsWith("public/")) return { key: "public", label: "Public output" };
  if (filePath.startsWith("prompts/")) return { key: "prompt", label: "Prompt" };
  if (filePath.startsWith("experiments/")) return { key: "experiment", label: "Experiment" };
  if (filePath.startsWith("scripts/")) return { key: "automation", label: "Automation" };
  if (filePath.endsWith(".md")) return { key: "docs", label: "Docs" };
  return { key: "work", label: "작업 결과" };
}

function getDefaultTitle(category, changes) {
  if (category.key === "automation") return "작업 결과 자동 게시 훅 추가";
  if (category.key === "public") return "홈 피드 공개 출력 업데이트";
  if (category.key === "asset") return "공개 아트 에셋 업데이트";
  if (category.key === "generated") return "생성 아트 결과 업데이트";
  if (category.key === "experiment") return "리소스 실험 결과 업데이트";
  if (category.key === "prompt") return "프롬프트 기록 업데이트";

  if (changes.length === 1) {
    return `${path.basename(changes[0].path)} 업데이트`;
  }

  return "작업 결과 업데이트";
}

function getDefaultSummary(files, hookInput) {
  const finalMessage = String(hookInput.final_message || hookInput.message || "").trim();

  if (finalMessage && finalMessage.length <= 180) {
    return finalMessage;
  }

  if (files.length === 0) {
    return "공개 가능한 변경은 없지만 강제 게시로 기록했습니다.";
  }

  const preview = files.slice(0, 4).join(", ");
  const suffix = files.length > 4 ? ` 외 ${files.length - 4}개` : "";
  return `변경 파일 ${files.length}개: ${preview}${suffix}`;
}

function getDefaultHref(files) {
  const htmlFile = files.find((filePath) => filePath.startsWith("public/") && filePath.endsWith(".html"));

  if (htmlFile) {
    return `./${htmlFile.replace(/^public\//, "")}`;
  }

  const publicFile = files.find((filePath) => filePath.startsWith("public/"));

  if (publicFile && !publicFile.endsWith(".json")) {
    return `./${publicFile.replace(/^public\//, "")}`;
  }

  return "./index.html";
}

function hasConflictMarkers(filePath) {
  const absolutePath = path.join(repoRoot, filePath);

  if (!fs.existsSync(absolutePath)) return false;
  if (!textExtensions.has(path.extname(filePath))) return false;

  const stats = fs.statSync(absolutePath);
  if (stats.size > 1024 * 1024) return false;

  const content = fs.readFileSync(absolutePath, "utf8");
  return /^(<<<<<<<|=======|>>>>>>>)( |$)/m.test(content);
}

function hashFile(filePath) {
  const absolutePath = path.join(repoRoot, filePath);

  if (!fs.existsSync(absolutePath)) return "deleted";

  const stats = fs.statSync(absolutePath);
  if (stats.isDirectory()) return "directory";
  if (stats.size > 2 * 1024 * 1024) {
    return `${stats.size}:${stats.mtimeMs}`;
  }

  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

function runGitCheck(args) {
  try {
    return { ok: true, output: git(args) };
  } catch (error) {
    return {
      ok: false,
      output: String(error.stdout || error.stderr || error.message || "").trim(),
    };
  }
}

function git(args, settings = {}) {
  try {
    return execFileSync("git", ["-C", repoRoot, ...args], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    if (settings.allowFailure) return "";
    throw error;
  }
}

function readJson(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(`${filePath}.tmp`, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(`${filePath}.tmp`, filePath);
}

function writeState(value) {
  writeJson(statePath, value);
}

function finish(result) {
  if (!options.quiet) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  }
}

function normalizeGitPath(filePath) {
  return filePath.replace(/^"|"$/g, "").replace(/\\/g, "/");
}

function normalizePath(filePath) {
  return path.resolve(String(filePath || "."));
}

function isInsidePath(child, parent) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function formatTimestamp(date) {
  return date.toISOString().replace(/[-:]/g, "").replace(/\..+$/, "Z");
}
