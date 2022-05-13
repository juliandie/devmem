
CC=gcc
CFLAGS=-g -Wall -I.
CSRC=$(wildcard *.c)
OBJS=$(CSRC:%.c=%.o)
BIN=devmem

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(CFLAGS) $< -o $@

%.o: %.c %.h
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf *.o devmem

