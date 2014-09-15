obj-m := emce.o

KVERSION ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KVERSION)/build
PWD := $(shell pwd)

modules:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) modules
modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD) modules_install
