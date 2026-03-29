const javaInput = document.getElementById("javaInput");
const cppOutput = document.getElementById("cppOutput");
const transpileBtn = document.getElementById("transpileBtn");
const copyBtn = document.getElementById("copyBtn");
const toast = document.getElementById("toast");

function showToast(message, isError = false) {
  toast.textContent = message;
  toast.classList.toggle("error", isError);
  toast.classList.add("show");
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => toast.classList.remove("show"), 3200);
}

async function transpile() {
  const source = javaInput.value;
  transpileBtn.disabled = true;
  copyBtn.disabled = true;
  cppOutput.innerHTML = "<code>// Transpiling…</code>";

  try {
    const res = await fetch("/api/transpile", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ source }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(data.error || `HTTP ${res.status}`);
    }
    const cpp = data.cpp ?? "";
    const escaped = cpp
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
    cppOutput.innerHTML = `<code>${escaped}</code>`;
    copyBtn.disabled = !cpp.trim();
  } catch (e) {
    cppOutput.innerHTML = `<code>// Error: ${String(e.message || e)}</code>`;
    showToast(String(e.message || e), true);
    copyBtn.disabled = true;
  } finally {
    transpileBtn.disabled = false;
  }
}

transpileBtn.addEventListener("click", transpile);

copyBtn.addEventListener("click", async () => {
  const code = cppOutput.textContent || "";
  if (!code.trim()) return;
  try {
    await navigator.clipboard.writeText(code);
    showToast("Copied to clipboard");
  } catch {
    showToast("Copy failed", true);
  }
});

document.addEventListener("keydown", (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
    e.preventDefault();
    transpile();
  }
});
