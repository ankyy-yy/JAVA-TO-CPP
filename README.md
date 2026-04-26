# Java-to-C++

## 🌐 Live Demo

👉 https://java-to-cpp-1.onrender.com/

Educational **subset** transpiler from Java-like source to C++17, with:

- **frontend/** — dark glassmorphism web UI (`index.html`, `style.css`, `script.js`)
- **server.js** — Express server; `POST /api/transpile` runs the native `j2cpp` binary
- **lexer.l** / **parser.y** — Flex/Bison front end that emits C++ text
- **main.c** — CLI driver: `j2cpp input.java output.cpp`
- **Makefile** — builds `j2cpp` (or `j2cpp.exe` on Windows toolchains)
- **test.java**, **ArrayTest.java**, **test_array.java** — sample inputs

## Prerequisites

| Component | Purpose |
|-----------|---------|
| Node.js 18+ | Web UI and API |
| flex, bison, gcc/clang | Build `j2cpp` |

On **Windows**, install [MSYS2](https://www.msys2.org/) (or WSL), then install `flex`, `bison`, and a C compiler; ensure they are on your `PATH` when running `make`. The MinGW `gcc` alone is not enough without flex/bison.

## Build the native transpiler

```bash
make
```

Produces `j2cpp` (Unix) or `j2cpp.exe` (MinGW) in the project root.

Smoke test (Unix shell):

```bash
make test
```

Or manually:

```bash
./j2cpp test.java out.cpp
g++ -std=c++17 -Wall -o prog out.cpp
./prog
```

## Run the web interface

```bash
npm install
npm start
```

Open [http://localhost:3000](http://localhost:3000). Paste Java, click **Transpile** (or **Ctrl+Enter**). The server shells out to `j2cpp`; if the binary is missing, the API returns an error explaining that you need to run `make` first.

## Supported language subset

Rough mapping:

| Java | C++ |
|------|-----|
| `int`, `boolean`, `String` | `int`, `bool`, `string` |
| `int[]` / `new int[n]` | `vector<int>` / `vector<int>(n)` |
| `System.out.println(expr)` | `cout << expr << endl` |
| `public static void main(String[] args)` | `int main(int argc, char* argv[])` |
| `static` fields | `static` globals at file scope |

**Not** supported: packages/imports (parsed but ignored for codegen), inheritance, generics, exceptions, `switch`, method calls on objects, string `+` concatenation, most of the standard library, and full Java semantics.

Place **static fields before** `main` in the source if you use them; the emitter writes declarations in parse order (C++ requires a sensible ordering at file scope).

## Project layout

```
java-to-cpp/
├── frontend/           # Web interface
│   ├── index.html
│   ├── style.css
│   └── script.js
├── server.js           # Node.js web server
├── package.json
├── lexer.l             # Flex lexer
├── parser.y            # Bison grammar + codegen
├── main.c              # CLI entry
├── Makefile
├── test.java           # Broader subset test
├── ArrayTest.java      # Array-focused test
├── test_array.java     # Additional array cases
└── README.md
```

## License

MIT
