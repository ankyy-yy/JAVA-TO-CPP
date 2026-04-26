const cors = require("cors");
const express = require("express");
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");

const app = express();
const PORT = 3000;
const NODE_ENV = process.env.NODE_ENV || "development";
const ROOT = __dirname;
const FRONTEND = path.join(ROOT, "frontend");

// On Linux (Render) use /tmp for temp files to avoid permission issues
// and to keep them off the ephemeral disk root.
const TMP_DIR = process.platform === "win32"
  ? ROOT
  : (process.env.TMPDIR || "/tmp");

const COMPILER_NAME = process.platform === "win32" ? "j2cpp.exe" : "j2cpp";
const COMPILER_PATH = path.join(ROOT, COMPILER_NAME);

const EXEC_TIMEOUT = 10000; // 10 s per-process timeout
const COMPILE_TIMEOUT = 20000; // 20 s for compilation

// ── Middleware ────────────────────────────────────────────
app.use(cors({
  origin: "*"
}));

app.use(express.json({ limit: "2mb" }));

// Basic security headers
app.use((_req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-XSS-Protection", "1; mode=block");
  next();
});

app.use(express.static(FRONTEND));

/* ────────────────────────────────────────────────────────
   Helper: run a command and return { stdout, stderr, code }
   ──────────────────────────────────────────────────────── */
function runCmd(cmd, args, opts = {}) {
  return new Promise((resolve) => {
    const timeoutMs = opts.timeout || EXEC_TIMEOUT;
    let timedOut = false;

    const child = spawn(cmd, args, {
      cwd: opts.cwd || ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      shell: process.platform === "win32",
    });

    let stdout = "";
    let stderr = "";

    // Hard kill after timeout
    const timer = setTimeout(() => {
      timedOut = true;
      try { child.kill("SIGKILL"); } catch (_) {}
    }, timeoutMs);

    child.stdout.on("data", (d) => (stdout += d.toString()));
    child.stderr.on("data", (d) => (stderr += d.toString()));

    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ stdout: "", stderr: err.message, code: -1 });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      if (timedOut) {
        resolve({ stdout, stderr: "Process timed out after " + timeoutMs + "ms", code: -1 });
      } else {
        resolve({ stdout, stderr, code: code ?? -1 });
      }
    });
  });
}

/* ────────────────────────────────────────────────────────
   Helper: safely delete a list of files / dirs
   ──────────────────────────────────────────────────────── */
function cleanupFiles(files) {
  files.forEach((f) => {
    try {
      if (!f) return;
      const stat = fs.statSync(f);
      if (stat.isDirectory()) {
        fs.rmSync(f, { recursive: true, force: true });
      } else {
        fs.unlinkSync(f);
      }
    } catch (_) {}
  });
}

/* ────────────────────────────────────────────────────────
   Transpile + tokenize + parse-tree
   ──────────────────────────────────────────────────────── */
function runNativeTranspiler(javaSource) {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(COMPILER_PATH)) {
      return reject(
        new Error(
          "Native transpiler binary not found. " +
          "On Render it is built automatically. " +
          "Locally on Windows run: make (via MSYS2/WSL)."
        )
      );
    }

    const id = Date.now() + "_" + Math.random().toString(36).slice(2, 8);
    const tmpIn   = path.join(TMP_DIR, `.tmp_${id}.java`);
    const tmpOut  = path.join(TMP_DIR, `.tmp_${id}.cpp`);
    const tmpTok  = path.join(TMP_DIR, `.tmp_${id}_tokens.txt`);
    const tmpTree = path.join(TMP_DIR, `.tmp_${id}_tree.txt`);

    try {
      fs.writeFileSync(tmpIn, javaSource, "utf8");
    } catch (e) {
      return reject(e);
    }

    const child = spawn(COMPILER_PATH, [tmpIn, tmpOut, tmpTok, tmpTree], {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stderr = "";
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("error", (err) => {
      cleanupFiles([tmpIn, tmpOut, tmpTok, tmpTree]);
      reject(err);
    });

    child.on("close", (code) => {
      let cpp = "";
      let tokens = [];
      let parseTree = "";

      try { if (fs.existsSync(tmpOut)) cpp = fs.readFileSync(tmpOut, "utf8"); } catch (_) {}

      try {
        if (fs.existsSync(tmpTok)) {
          const raw = fs.readFileSync(tmpTok, "utf8").trim();
          if (raw) {
            tokens = raw.split("\n").map((line) => {
              const idx = line.indexOf("\t");
              if (idx === -1) return { type: line, value: "" };
              return { type: line.slice(0, idx), value: line.slice(idx + 1) };
            });
          }
        }
      } catch (_) {}

      try { if (fs.existsSync(tmpTree)) parseTree = fs.readFileSync(tmpTree, "utf8"); } catch (_) {}

      cleanupFiles([tmpIn, tmpOut, tmpTok, tmpTree]);

      if (code !== 0 && !cpp) {
        return reject(new Error(stderr || `j2cpp exited with code ${code}`));
      }

      resolve({
        translatedCode: cpp,
        tokens,
        parseTree,
        parserErrors: stderr ? stderr.trim() : "",
      });
    });
  });
}

/* ────────────────────────────────────────────────────────
   POST /api/transpile
   ──────────────────────────────────────────────────────── */
app.post("/api/transpile", async (req, res) => {
  const source = typeof req.body?.source === "string" ? req.body.source : "";
  if (!source.trim()) {
    return res.status(400).json({ error: "Missing or empty `source` string." });
  }

  // Basic size guard (prevent huge payloads)
  if (source.length > 50_000) {
    return res.status(413).json({ error: "Source code too large (max 50 KB)." });
  }

  try {
    const result = await runNativeTranspiler(source);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ────────────────────────────────────────────────────────
   POST /api/compile
   Compile AND run Java source and/or generated C++ source.
   Body: { javaCode, cppCode }
   Returns:
     {
       javaCompile: { success, output, error },
       javaRun:     { ran, output, error },
       cppCompile:  { success, output, error },
       cppRun:      { ran, output, error },
     }
   ──────────────────────────────────────────────────────── */
app.post("/api/compile", async (req, res) => {
  const { javaCode, cppCode } = req.body || {};
  const id = Date.now() + "_" + Math.random().toString(36).slice(2, 8);
  const result = {
    javaCompile: { success: false, output: "", error: "" },
    javaRun:     { ran: false,    output: "", error: "" },
    cppCompile:  { success: false, output: "", error: "" },
    cppRun:      { ran: false,    output: "", error: "" },
  };

  /* ── Java compile + run ────────────────────────────── */
  if (javaCode && typeof javaCode === "string" && javaCode.trim()) {
    if (javaCode.length > 50_000) {
      result.javaCompile.error = "Java source too large (max 50 KB).";
    } else {
      const classMatch = javaCode.match(/(?:^|\s)class\s+(\w+)/m);
      const className  = classMatch ? classMatch[1] : "Main";
      const tmpDir     = path.join(TMP_DIR, `.tmp_java_${id}`);
      const javaFile   = path.join(tmpDir, `${className}.java`);

      try {
        fs.mkdirSync(tmpDir, { recursive: true });
        fs.writeFileSync(javaFile, javaCode, "utf8");

        // Compile
        const jc = await runCmd("javac", [javaFile], { cwd: tmpDir, timeout: COMPILE_TIMEOUT });
        if (jc.code === 0) {
          result.javaCompile.success = true;
          result.javaCompile.output  = "✅ Java compilation successful";
        } else {
          result.javaCompile.output = (jc.stderr || jc.stdout || "Compilation failed").trim();
          result.javaCompile.error  = result.javaCompile.output;
        }

        // Run only if compilation succeeded
        if (result.javaCompile.success) {
          const jr = await runCmd("java", ["-cp", tmpDir, className], {
            cwd: tmpDir,
            timeout: EXEC_TIMEOUT,
          });
          result.javaRun.ran    = true;
          result.javaRun.output = (jr.stdout || "").trimEnd();
          result.javaRun.error  = (jr.stderr || "").trimEnd();
          if (!result.javaRun.output && !result.javaRun.error) {
            result.javaRun.output = "No output";
          } else if (jr.code !== 0 && !result.javaRun.output) {
            result.javaRun.error = result.javaRun.error || `Java process exited with code ${jr.code}`;
          }
        }
      } catch (e) {
        result.javaCompile.error = e.message;
      } finally {
        cleanupFiles([tmpDir]);
      }
    }
  }

  /* ── C++ compile + run ─────────────────────────────── */
  if (cppCode && typeof cppCode === "string" && cppCode.trim()) {
    if (cppCode.length > 50_000) {
      result.cppCompile.error = "C++ source too large (max 50 KB).";
    } else {
      const exeExt  = process.platform === "win32" ? ".exe" : "";
      const cppFile = path.join(TMP_DIR, `.tmp_cpp_${id}.cpp`);
      const exeFile = path.join(TMP_DIR, `.tmp_cpp_${id}${exeExt}`);

      try {
        fs.writeFileSync(cppFile, cppCode, "utf8");

        const cc = await runCmd(
          "g++",
          ["-std=c++17", "-Wall", "-o", exeFile, cppFile],
          { timeout: COMPILE_TIMEOUT }
        );

        if (cc.code === 0) {
          result.cppCompile.success = true;
          result.cppCompile.output  = "✅ C++ compilation successful";
        } else {
          result.cppCompile.output = (cc.stderr || cc.stdout || "Compilation failed").trim();
          result.cppCompile.error  = result.cppCompile.output;
        }

        // Run only if compilation succeeded
        if (result.cppCompile.success && fs.existsSync(exeFile)) {
          // chmod +x on Linux
          if (process.platform !== "win32") {
            try { fs.chmodSync(exeFile, 0o755); } catch (_) {}
          }

          const absExe = path.resolve(exeFile);
          const cr = await runCmd(absExe, [], { timeout: EXEC_TIMEOUT, cwd: TMP_DIR });
          result.cppRun.ran    = true;
          result.cppRun.output = (cr.stdout || "").trimEnd();
          result.cppRun.error  = (cr.stderr || "").trimEnd();
          if (!result.cppRun.output && !result.cppRun.error) {
            result.cppRun.output = "No output";
          } else if (cr.code !== 0 && !result.cppRun.output) {
            result.cppRun.error = result.cppRun.error || `C++ process exited with code ${cr.code}`;
          }
        }
      } catch (e) {
        result.cppCompile.error = e.message;
      } finally {
        cleanupFiles([cppFile, exeFile]);
      }
    }
  }

  res.json(result);
});

/* ────────────────────────────────────────────────────────
   Health-check endpoint (used by Render)
   ──────────────────────────────────────────────────────── */
app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    platform: process.platform,
    env: NODE_ENV,
    transpilerReady: fs.existsSync(COMPILER_PATH),
  });
});

/* ────────────────────────────────────────────────────────
   Catch-all: serve the frontend SPA
   ──────────────────────────────────────────────────────── */
app.get("*", (_req, res) => {
  res.sendFile(path.join(FRONTEND, "index.html"));
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Server running at: http://localhost:${PORT}`);
  console.log(`[Java-to-C++ Transpiler] Listening on port ${PORT} (${NODE_ENV})`);
  console.log(
    `[Transpiler binary] ${COMPILER_PATH} — exists: ${fs.existsSync(COMPILER_PATH)}`
  );
});
