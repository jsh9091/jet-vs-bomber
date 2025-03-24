all:
	dasm *.asm -f3 -v0 -oJetVsBomber.bin

run:
	stella cart.bin
