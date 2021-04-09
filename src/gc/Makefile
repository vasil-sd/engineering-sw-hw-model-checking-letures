CC=g++

all: test

test: gctest
	./gctest

gctest: tests/gc_test.cpp
	$(CC) -std=c++17 -ggdb -O0 -I. -I../memalloc -o $@ $<
