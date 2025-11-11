main: main.o
	$(CC) $(LDFLAGS) main.o -o rename_recorder

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

clean:
	rm *.o rename_recorder