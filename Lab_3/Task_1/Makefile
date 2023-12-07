CC := gcc # cc - compiler collection, using simplified calculated variables
TOOLCHAIN := arm-linux-gnuebihf-

native:	clear
	$(CC)-c src/hello.c -Iinc -o hello.o
	ar rcs libhello.a hello.o
	$(CC) -c src/main.c -Iinc -o main.o
	$(CC) main.o -L./ -lhello -o dont_run_x86.elf
	rm *.o
	rm *.a

native_debug: clear
	$(CC)-c src/hello.c -Iinc -o hello.o
	ar rcs libhello.a hello.o
	$(CC) -c src/main.c -Iinc -o main.o
	$(CC) main.o -L./ -lhello -o dont_run_x86.elf -g
	rm *.o
	rm *.a

cross: clear
	$(TOOLCHAIN)$(CC) -c src/hello.c -Iinc -o hello.o
	ar rcs hello.o libhello.a
	$(TOOLCHAIN)$(CC) -c src/main.c -Iinc -o main.o
	$(TOOLCHAIN)$(CC) main.o -L./ -lhello -o dont_run_arm.elf

clear:
	rm -f *.o
	rm -f *.elf
