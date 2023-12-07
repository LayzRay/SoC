CC := gcc # cc - compiler collection, using simplified calculated variables

native:	clear
	$(CC)-c -fpic src/hello.c -Iinc -o hello.o
	$(CC)-c src/main.c -Iinc -o main.o
	$(CC) main.o -L./ -lhello -o say_hi.elf
	rm *.o

clear:
	rm -f *.o
	rm -f *.elf
