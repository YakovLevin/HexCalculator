#format is target-name: target dependencies
#{-tab-}actions

# All Targets
all: calc

# Tool invocations
# Executable "hello" depends on the files main.o and asm.o.
calc: calc.o
	gcc -m32 -g -Wall -o calc calc.o 

 
calc.o: calc.s
	nasm -g -f elf32 -w+all -o calc.o calc.s


#tell make that "clean" is not a file name!
.PHONY: clean

#Clean the build directory
clean: 
	rm -f *.o calc
