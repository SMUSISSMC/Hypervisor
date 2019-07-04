# rpi2-hyp-boot
starting core in HYP mode, and boot up kernel in SVC mode.

# Building
build with arm-linux-gnueabihf-gcc arm-linux-gnueabihf-ld arm-linux-gnueabihf-objcopy
run ./mmm.sh will create binary file bootblk.bin

build your linux kernel, and do the following:

mv kernel7.img kernel7.img.bak
cat bootblk.bin kernel7.img.bak > kernel7.img

The new kernel7.img is the final image.

And at config.txt
add:

kernel_old=1

# Reference
http://blog.flexvm.es/?p=139
