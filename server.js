const express = require("express");
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");

const app = express();
const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const FRONTEND = path.join(ROOT, "frontend");
const COMPILER_NAME = process.platform === "win32" ? "j2cpp.exe" : "j2cpp";
const COMPILER_PATH = path.join(ROOT, COMPILER_NAME);

app.use(express.json({ limit: "2mb" }));
app.use(express.static(FRONTEND));

function runNativeTranspiler(javaSource, callback) {
  if (!fs.existsSync(COMPILER_PATH)) {
    return callback(
      new Error(
        "Native transpiler not built. Run `make` (or build on WSL/MSYS2) so j2cpp exists in the project root."
      )
    );
  }

  const tmpIn = path.join(ROOT, ".transpile_in.java");
  const tmpOut = path.join(ROOT, ".transpile_out.cpp");

  try {
    fs.writeFileSync(tmpIn, javaSource, "utf8");
  } catch (e) {
    return callback(e);
  }

  const child = spawn(COMPILER_PATH, [tmpIn, tmpOut], {
    cwd: ROOT,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let stderr = "";
  child.stderr.on("data", (d) => {
    stderr += d.toString();
  });

  child.on("error", (err) => callback(err));

  child.on("close", (code) => {
    if (code !== 0) {
      return callback(new Error(stderr || `j2cpp exited with code ${code}`));
    }
    try {
      const cpp = fs.readFileSync(tmpOut, "utf8");
      callback(null, cpp);
    } catch (e) {
      callback(e);
    } finally {
      try {
        fs.unlinkSync(tmpIn);
      } catch (_) {}
      try {
        fs.unlinkSync(tmpOut);
      } catch (_) {}
    }
  });
}

app.post("/api/transpile", (req, res) => {
  const source = typeof req.body?.source === "string" ? req.body.source : "";
  if (!source.trim()) {
    return res.status(400).json({ error: "Missing or empty `source` string." });
  }

  runNativeTranspiler(source, (err, cpp) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json({ cpp });
  });
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(FRONTEND, "index.html"));
});

app.listen(PORT, () => {
  console.log(`Java-to-C++ UI at http://localhost:${PORT}`);
});
