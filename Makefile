# Requires flex, bison, and a C compiler (gcc or clang).
# On Windows, use MSYS2, WSL, or Cygwin so flex/bison/gcc are on PATH.

CC      ?= gcc
CFLAGS  ?= -Wall -Wextra -O2
LDFLAGS ?=

BISON = bison -d
FLEX  = flex

.PHONY: all clean test

all: j2cpp

parser.tab.c parser.tab.h: parser.y
	$(BISON) parser.y

lex.yy.c: lexer.l parser.tab.h
	$(FLEX) lexer.l

j2cpp: lex.yy.c parser.tab.c main.c
	$(CC) $(CFLAGS) -o $@ lex.yy.c parser.tab.c main.c $(LDFLAGS)

clean:
	rm -f j2cpp j2cpp.exe lex.yy.c parser.tab.c parser.tab.h

# Smoke-test the native binary against bundled Java samples (requires g++).
test: j2cpp test.java
	./j2cpp test.java _out.cpp && g++ -std=c++17 -Wall -o _out _out.cpp && ./_out
	rm -f _out _out.cpp
