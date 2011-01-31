ifneq ($(KERNELRELEASE),)
    obj-m := emce.o
else
    KDIR:=$(shell pwd)/../linux-2.6-xlnx/
    PWD:=$(shell pwd)
default:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules modules_install
endif
