# Java-to-C++ Transpiler — Build System
# Requires: flex, bison, gcc
# On Windows: uses MSYS2 tools from C:/msys64

# Detect Windows MSYS2 tools
ifeq ($(OS),Windows_NT)
  BISON ?= C:/msys64/usr/bin/bison.exe
  FLEX  ?= C:/msys64/usr/bin/flex.exe
  CC    ?= C:/msys64/mingw64/bin/gcc.exe
  GPP   ?= C:/msys64/mingw64/bin/g++.exe
else
  BISON ?= bison
  FLEX  ?= flex
  CC    ?= gcc
  GPP   ?= g++
endif

CFLAGS  ?= -Wall -O2
TARGET   = j2cpp$(if $(filter Windows_NT,$(OS)),.exe,)

.PHONY: all clean test

all: $(TARGET)

parser.tab.c parser.tab.h: parser.y
	$(BISON) -d parser.y

lex.yy.c: lexer.l parser.tab.h
	$(FLEX) lexer.l

$(TARGET): lex.yy.c parser.tab.c main.c
	$(CC) $(CFLAGS) -o $@ lex.yy.c parser.tab.c main.c

clean:
	rm -f j2cpp j2cpp.exe lex.yy.c parser.tab.c parser.tab.h
	rm -f .tmp_* *.class out.cpp out.exe out_arr.cpp out_arr.exe

# Smoke test: transpile test.java → out.cpp → compile → run
test: $(TARGET) test.java
	./$(TARGET) test.java _out.cpp _tokens.txt _tree.txt
	@echo "--- Tokens ---"
	@cat _tokens.txt
	@echo ""
	@echo "--- Parse Tree ---"
	@cat _tree.txt
	@echo ""
	@echo "--- Generated C++ ---"
	@cat _out.cpp
	@echo ""
	@echo "--- Compiling C++ ---"
	$(GPP) -std=c++17 -Wall -o _out _out.cpp
	@echo "--- Running C++ ---"
	./_out
	rm -f _out _out.cpp _out.exe _tokens.txt _tree.txt
