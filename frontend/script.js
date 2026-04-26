/* ═══════════════════════════════════════════════════════
   Java-to-C++ Transpiler — Frontend Logic
   ═══════════════════════════════════════════════════════ */
  const API_BASE_URL = "";

document.addEventListener("DOMContentLoaded", () => {
  const app = new TranspilerApp();
  app.init();
  window.__app = app;
});

class TranspilerApp {
  constructor() {
    // Code editors
    this.javaInput = null;
    this.cppOutput = null;
    this.javaLineNums = null;
    this.cppLineNums = null;
    // Buttons
    this.convertBtn = null;
    this.convertText = null;
    // Analysis tab elements
    this.tokenBody = null;
    this.tokenCount = null;
    this.tokenInfo = null;
    this.treeOutput = null;
    this.treeInfo = null;
    // Java compile+run elements
    this.javaCompileOutput = null;
    this.javaCompileStatus = null;
    this.javaRunSection = null;
    this.javaRunOutput = null;
    this.javaRunBadge = null;
    // C++ compile+run elements
    this.cppCompileOutput = null;
    this.cppCompileStatus = null;
    this.cppRunSection = null;
    this.cppRunOutput = null;
    this.cppRunBadge = null;
    // Stats
    this.stats = { conversions: 0, tokens: 0, javaComp: 0, cppComp: 0 };
  }

  /* ── Initialization ──────────────────────────────────── */
  init() {
    this.cacheElements();
    this.bindEvents();
    this.loadStats();
    this.loadExampleCode();
    this.updateLineNumbers(this.javaInput, this.javaLineNums);
  }

  cacheElements() {
    this.javaInput         = document.getElementById("java-input");
    this.cppOutput         = document.getElementById("cpp-output");
    this.javaLineNums      = document.getElementById("java-line-numbers");
    this.cppLineNums       = document.getElementById("cpp-line-numbers");
    this.convertBtn        = document.getElementById("convert-btn");
    this.convertText       = document.getElementById("convert-text");
    this.tokenBody         = document.getElementById("token-body");
    this.tokenCount        = document.getElementById("token-count");
    this.tokenInfo         = document.getElementById("token-info");
    this.treeOutput        = document.getElementById("tree-output");
    this.treeInfo          = document.getElementById("tree-info");
    // Java
    this.javaCompileOutput = document.getElementById("java-compile-output");
    this.javaCompileStatus = document.getElementById("java-compile-status");
    this.javaRunSection    = document.getElementById("java-run-section");
    this.javaRunOutput     = document.getElementById("java-run-output");
    this.javaRunBadge      = document.getElementById("java-run-badge");
    // C++
    this.cppCompileOutput  = document.getElementById("cpp-compile-output");
    this.cppCompileStatus  = document.getElementById("cpp-compile-status");
    this.cppRunSection     = document.getElementById("cpp-run-section");
    this.cppRunOutput      = document.getElementById("cpp-run-output");
    this.cppRunBadge       = document.getElementById("cpp-run-badge");
  }

  bindEvents() {
    this.convertBtn.addEventListener("click", () => this.transpile());

    document.getElementById("clear-input").addEventListener("click", () => this.clearAll());
    document.getElementById("load-example").addEventListener("click", () => {
      this.loadExampleCode();
      this.updateLineNumbers(this.javaInput, this.javaLineNums);
      this.toast("Example loaded", "info");
    });
    document.getElementById("copy-output").addEventListener("click", () => this.copyOutput());
    document.getElementById("download-output").addEventListener("click", () => this.downloadOutput());

    document.getElementById("compile-java-btn").addEventListener("click", () => this.compileAndRun("java"));
    document.getElementById("compile-cpp-btn").addEventListener("click", () => this.compileAndRun("cpp"));

    document.querySelectorAll(".tab-btn").forEach((btn) => {
      btn.addEventListener("click", () => this.switchTab(btn.dataset.tab));
    });

    this.javaInput.addEventListener("input", () => this.updateLineNumbers(this.javaInput, this.javaLineNums));
    this.javaInput.addEventListener("scroll", () => this.syncScroll(this.javaInput, this.javaLineNums));
    this.cppOutput.addEventListener("scroll", () => this.syncScroll(this.cppOutput, this.cppLineNums));

    this.javaInput.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        this.transpile();
      }
      if (e.key === "Tab") {
        e.preventDefault();
        const start = this.javaInput.selectionStart;
        const end   = this.javaInput.selectionEnd;
        this.javaInput.value =
          this.javaInput.value.substring(0, start) + "    " + this.javaInput.value.substring(end);
        this.javaInput.selectionStart = this.javaInput.selectionEnd = start + 4;
        this.updateLineNumbers(this.javaInput, this.javaLineNums);
      }
    });
  }

  /* ── Example Code ────────────────────────────────────── */
  loadExampleCode() {
    this.javaInput.value = `public class Demo {
  static int n = 5;

  static int factorial(int num) {
    if (num <= 1) {
      return 1;
    }
    return num * factorial(num - 1);
  }

  static int sumTo(int limit) {
    int total = 0;
    for (int i = 1; i <= limit; i++) {
      total += i;
    }
    return total;
  }

  public static void main(String[] args) {
    // Function calls with parameters
    int fact = factorial(5);
    System.out.println(fact);

    // String concatenation in println
    int s = sumTo(10);
    System.out.println("Sum 1-10 = " + s);

    // Array usage
    int[] a = new int[n];
    int i = 0;
    while (i < n) {
      a[i] = i * 2;
      i = i + 1;
    }

    // Print array elements
    i = 0;
    while (i < n) {
      System.out.println(a[i]);
      i = i + 1;
    }

    // If-else
    int x = 10;
    if (x > 5) {
      System.out.println(x);
    } else {
      System.out.println(0);
    }
  }
}`;
  }

  /* ── Transpile ───────────────────────────────────────── */
async transpile() {
  const source = this.javaInput.value.trim();

  if (!source) {
    this.toast("Please enter some Java code first.", "error");
    return;
  }

  this.setLoading(true);

  try {
    const res = await fetch(`${API_BASE_URL}/api/transpile`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ source }),
    });

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.error || "Transpilation failed");
    }

    // ✅ Update UI
    this.cppOutput.value = data.translatedCode || "";
    this.renderTokens(data.tokens || []);
    this.renderParseTree(data.parseTree || "");

    this.toast("Transpilation successful!", "success");

  } catch (err) {
    console.error(err);
    this.toast(err.message || "Error during transpilation", "error");
  } finally {
    this.setLoading(false);
  }
}

  /* ── Compile + Run (unified for Java and C++) ────────── */
  async compileAndRun(lang) {
    const isJava = lang === "java";
    const code   = isJava ? this.javaInput.value.trim() : this.cppOutput.value.trim();

    if (!code) {
      const msg = isJava
        ? "No Java code to compile."
        : "No C++ code to compile. Transpile first.";
      this.toast(msg, "error");
      return;
    }

    const btnId       = isJava ? "compile-java-btn"    : "compile-cpp-btn";
    const btnLabel    = isJava ? "Compile &amp; Run Java" : "Compile &amp; Run C++";
    const statusEl    = isJava ? this.javaCompileStatus : this.cppCompileStatus;
    const compileEl   = isJava ? this.javaCompileOutput : this.cppCompileOutput;
    const runSection  = isJava ? this.javaRunSection    : this.cppRunSection;
    const runOutputEl = isJava ? this.javaRunOutput     : this.cppRunOutput;
    const runBadgeEl  = isJava ? this.javaRunBadge      : this.cppRunBadge;

    const btn = document.getElementById(btnId);
    btn.disabled = true;
    btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.5" stroke-dasharray="4 2"/></svg> Compiling…`;

    compileEl.textContent = isJava ? "Compiling with javac..." : "Compiling with g++ -std=c++17...";
    compileEl.className   = "compile-output";
    statusEl.textContent  = "";
    statusEl.className    = "compile-status";
    runSection.style.display = "none";

    const body = isJava ? { javaCode: code } : { cppCode: code };

    try {
      const res = await fetch(`${API_BASE_URL}/api/compile`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();

      const compileData = isJava ? data.javaCompile : data.cppCompile;
      const runData     = isJava ? data.javaRun     : data.cppRun;

      // ── Compile result ──────────────────────────────
      if (compileData.success) {
        compileEl.textContent = compileData.output || "✅ Compilation successful";
        compileEl.classList.add("success");
        statusEl.textContent  = "✅ Compiled";
        statusEl.classList.add("success");
        if (isJava) { this.stats.javaComp++; } else { this.stats.cppComp++; }
        this.toast(`${isJava ? "Java" : "C++"} compiled successfully!`, "success");
      } else {
        compileEl.textContent = compileData.error || compileData.output || "❌ Compilation failed";
        compileEl.classList.add("error");
        statusEl.textContent  = "❌ Compile failed";
        statusEl.classList.add("error");
        this.toast(`${isJava ? "Java" : "C++"} compilation failed`, "error");
      }

      // ── Run result ──────────────────────────────────
      if (runData && runData.ran) {
        runSection.style.display = "block";
        const hasError  = !!runData.error;
        const hasOutput = !!runData.output;

        runOutputEl.textContent = hasOutput
          ? runData.output
          : (hasError ? runData.error : "(no output)");

        runOutputEl.className = "run-output" + (hasError && !hasOutput ? " error" : " success");
        runBadgeEl.textContent  = hasError && !hasOutput ? "❌ Runtime error" : "✅ Ran OK";
        runBadgeEl.className    = "run-status-badge " + (hasError && !hasOutput ? "error" : "success");

        if (hasError && hasOutput) {
          // stderr alongside stdout — show both
          runOutputEl.textContent = runData.output + "\n\n--- stderr ---\n" + runData.error;
        }
      }

      this.saveStats();
      this.updateStatsDisplay();

    } catch (err) {
      compileEl.textContent = "Network error: " + err.message;
      compileEl.classList.add("error");
      statusEl.textContent  = "❌ Error";
      statusEl.classList.add("error");
      this.toast("Request failed: " + err.message, "error");
    } finally {
      btn.disabled = false;
      btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M5 3l8 5-8 5V3z" fill="currentColor"/></svg> ${btnLabel}`;
    }
  }

  /* ── Render Tokens ───────────────────────────────────── */
  renderTokens(tokens) {
    this.tokenCount.textContent = tokens.length;

    if (tokens.length === 0) {
      this.tokenBody.innerHTML = `<tr class="token-placeholder"><td colspan="3">No tokens generated.</td></tr>`;
      this.tokenInfo.textContent = "No tokens available.";
      return;
    }

    this.tokenInfo.textContent = `${tokens.length} tokens generated by Flex lexer.`;

    let html = "";
    tokens.forEach((tok, i) => {
      const val = this.escapeHtml(tok.value);
      html += `<tr>
        <td>${i + 1}</td>
        <td>${tok.type}</td>
        <td>${val}</td>
      </tr>`;
    });

    this.tokenBody.innerHTML = html;
  }

  /* ── Render Parse Tree ───────────────────────────────── */
  renderParseTree(tree) {
    if (!tree || !tree.trim()) {
      this.treeOutput.textContent = "No parse tree generated.";
      this.treeInfo.textContent   = "Parse tree not available.";
      return;
    }

    this.treeInfo.textContent = "Parse tree generated by Bison parser.";

    const lines = tree.split("\n");
    let html = "";
    for (const line of lines) {
      if (!line.trim()) continue;
      const nodeMatch  = line.match(/^(\s*├─\s*)(\w+)$/);
      const leafMatch  = line.match(/^(\s*├─\s*)(\w+):\s*"(.*)"$/);
      const emptyLeaf  = line.match(/^(\s*├─\s*)(\w+):\s*""$/);

      if (leafMatch) {
        html += `<span class="tree-branch">${this.escapeHtml(leafMatch[1])}</span><span class="tree-leaf">${this.escapeHtml(leafMatch[2])}</span>: <span class="tree-value">"${this.escapeHtml(leafMatch[3])}"</span>\n`;
      } else if (emptyLeaf) {
        html += `<span class="tree-branch">${this.escapeHtml(emptyLeaf[1])}</span><span class="tree-leaf">${this.escapeHtml(emptyLeaf[2])}</span>\n`;
      } else if (nodeMatch) {
        html += `<span class="tree-branch">${this.escapeHtml(nodeMatch[1])}</span><span class="tree-node">${this.escapeHtml(nodeMatch[2])}</span>\n`;
      } else {
        html += this.escapeHtml(line) + "\n";
      }
    }

    this.treeOutput.innerHTML = html;
  }

  /* ── Tab Switching ───────────────────────────────────── */
  switchTab(tabId) {
    document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab-content").forEach((c) => c.classList.remove("active"));

    const btn     = document.querySelector(`.tab-btn[data-tab="${tabId}"]`);
    const content = document.getElementById(`content-${tabId}`);
    if (btn)     btn.classList.add("active");
    if (content) content.classList.add("active");
  }

  /* ── Line Numbers ────────────────────────────────────── */
  updateLineNumbers(textarea, lineNumEl) {
    const lines = textarea.value.split("\n").length;
    let html = "";
    for (let i = 1; i <= lines; i++) {
      html += i + "\n";
    }
    lineNumEl.textContent = html;
  }

  syncScroll(textarea, lineNumEl) {
    lineNumEl.scrollTop = textarea.scrollTop;
  }

  /* ── Utility ─────────────────────────────────────────── */
  clearAll() {
    this.javaInput.value = "";
    this.cppOutput.value = "";
    this.updateLineNumbers(this.javaInput, this.javaLineNums);
    this.updateLineNumbers(this.cppOutput, this.cppLineNums);

    this.tokenBody.innerHTML = `<tr class="token-placeholder"><td colspan="3">No tokens yet — transpile some code first.</td></tr>`;
    this.tokenCount.textContent = "0";
    this.tokenInfo.textContent  = 'Click "Transpile" to generate tokens from the lexer.';
    this.treeOutput.textContent = "No parse tree yet — transpile some code first.";
    this.treeInfo.textContent   = 'Click "Transpile" to generate the parse tree from the parser.';

    // Reset Java panel
    this.javaCompileOutput.textContent = 'Click "Compile & Run Java" to check if the original Java code compiles with javac.';
    this.javaCompileOutput.className   = "compile-output";
    this.javaCompileStatus.textContent = "";
    this.javaCompileStatus.className   = "compile-status";
    this.javaRunSection.style.display  = "none";
    this.javaRunOutput.textContent     = "";

    // Reset C++ panel
    this.cppCompileOutput.textContent = 'Click "Compile & Run C++" to check if the generated C++ code compiles with g++.';
    this.cppCompileOutput.className   = "compile-output";
    this.cppCompileStatus.textContent = "";
    this.cppCompileStatus.className   = "compile-status";
    this.cppRunSection.style.display  = "none";
    this.cppRunOutput.textContent     = "";

    this.toast("Cleared", "info");
  }

  async copyOutput() {
    const code = this.cppOutput.value;
    if (!code) { this.toast("No C++ code to copy.", "error"); return; }
    try {
      await navigator.clipboard.writeText(code);
      this.toast("Copied to clipboard!", "success");
    } catch {
      this.cppOutput.select();
      document.execCommand("copy");
      this.toast("Copied to clipboard!", "success");
    }
  }

  downloadOutput() {
    const code = this.cppOutput.value;
    if (!code) { this.toast("No C++ code to download.", "error"); return; }
    const blob = new Blob([code], { type: "text/plain" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href     = url;
    a.download = "output.cpp";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    this.toast("Downloaded output.cpp", "success");
  }

  setLoading(loading) {
    this.convertBtn.disabled = loading;
    if (loading) {
      this.convertBtn.classList.add("loading");
      this.convertText.textContent = "Working…";
    } else {
      this.convertBtn.classList.remove("loading");
      this.convertText.textContent = "Transpile";
    }
  }

  escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  /* ── Toast ───────────────────────────────────────────── */
  toast(message, type = "info") {
    const el = document.getElementById("toast");
    el.textContent = message;
    el.className   = `toast ${type}`;
    void el.offsetWidth;
    el.classList.remove("hidden");

    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => {
      el.classList.add("hidden");
    }, 3500);
  }

  /* ── Stats Persistence ───────────────────────────────── */
  loadStats() {
    try {
      const saved = localStorage.getItem("j2cpp_stats");
      if (saved) this.stats = JSON.parse(saved);
    } catch { /* ignore */ }
    this.updateStatsDisplay();
  }

  saveStats() {
    try { localStorage.setItem("j2cpp_stats", JSON.stringify(this.stats)); } catch { /* ignore */ }
  }

  updateStatsDisplay() {
    document.getElementById("stat-conversions").textContent = this.stats.conversions;
    document.getElementById("stat-tokens").textContent      = this.stats.tokens;
    document.getElementById("stat-java-comp").textContent   = this.stats.javaComp;
    document.getElementById("stat-cpp-comp").textContent    = this.stats.cppComp;
  }
}