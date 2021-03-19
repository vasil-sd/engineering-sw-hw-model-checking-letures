CC=g++

all: test

test: memtest
	./memtest

memtest: tests/memory_test.cpp
	$(CC) -std=c++17 -ggdb -O0 -I. -o $@ $<
