ARCH=powerpc
CROSS_COMPILE=powerpc-linux-
ifneq ($(KERNELRELEASE),)
    obj-m := emce.o
else
    KDIR:=$(shell pwd)/../../linux/
    PWD:=$(shell pwd)
default:
	ARCH=powerpc CROSS_COMPILE=powerpc-linux- $(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules
install:
	ARCH=powerpc CROSS_COMPILE=powerpc-linux- $(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules_install
endif
