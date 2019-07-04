CC=arm-linux-gnueabihf-gcc
LD=arm-linux-gnueabihf-ld.bfd
OBJCOPY=arm-linux-gnueabihf-objcopy
#CC=/home/nkhdo/QHQ/gcc-arm-none-eabi-4_9-2015q1/bin/arm-none-eabi-gcc
#LD=/home/nkhdo/QHQ/gcc-arm-none-eabi-4_9-2015q1/bin/arm-none-eabi-ld.bfd
#OBJCOPY=/home/nkhdo/QHQ/gcc-arm-none-eabi-4_9-2015q1/bin/arm-none-eabi-objcopy

CFLAGS += -O2 -march=armv7-a -nostartfiles -fomit-frame-pointer -nostdlib -fPIC


obj-hyp += ./stage2.o ./rpi2-hyp-boot.o

obj-y += $(obj-hyp)

$(CC) -O2 -march=armv7-a -nostartfiles -nostdlib -fPIC $(obj-y)

all: bootblk.bin

rpi2-hyp-boot.o: rpi2-hyp-boot.S
	$(CC) -O2 -march=armv7-a -nostartfiles -nostdlib rpi2-hyp-boot.S -c -o rpi2-hyp-boot.o

rpi2_hyp_boot: $(obj-y)
	$(LD) -pie --gc-sections -Bstatic -T rpi2-hyp-boot.lds -o rpi2-hyp-boot $(obj-y)

rpi2_hyp_boot.bin: rpi2_hyp_boot
	$(OBJCOPY) --gap-fill=0xff -O binary rpi2-hyp-boot rpi2-hyp-boot.bin

bootblk.bin: rpi2_hyp_boot.bin
	dd if=/dev/zero of=bootblk.bin bs=32k count=1
	dd if=rpi2-hyp-boot.bin of=bootblk.bin conv=notrunc

clean:
	@rm -f *.o *.bin rpi2-hyp-boot
	@rm -f ./rsa/*.o

