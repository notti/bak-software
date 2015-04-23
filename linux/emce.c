#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/device.h>
#include <linux/of_device.h>
#include <linux/of_platform.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/io.h>
#include <linux/interrupt.h>
#include <linux/spinlock.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/slab.h>
#include <linux/mm.h>
#include <asm/uaccess.h>

#define DRIVER_NAME "emce"
#define USER_MEM 4

#define EMCE_INTR_DISR_OFFSET  0x00000200
#define EMCE_INTR_DIER_OFFSET  0x00000208
#define EMCE_INTR_DGIER_OFFSET 0x0000021C
#define EMCE_INTR_IPISR_OFFSET 0x00000220
#define EMCE_INTR_IPIER_OFFSET 0x00000228

#define EMCE_RST_REG_OFFSET    0x00000100

#define EMCE_INTR_IPIR_MASK    0x00000004
#define EMCE_INTR_GIE_MASK     0x80000000

#define EMCE_SOFT_RESET        0x0000000A

#define REG0_OFFSET            0x00000000
#define REG1_OFFSET            0x00000004
#define REG2_OFFSET            0x00000008
#define REG3_OFFSET            0x0000000C
#define REG4_OFFSET            0x00000010
#define REG5_OFFSET            0x00000014


struct user_mem
{
	unsigned long start;
	unsigned long size;
	void __iomem *base_address;
};

struct emce_device
{
	struct cdev cdev;
	dev_t dev;
	unsigned long reg_start;
	unsigned long reg_size;
	void __iomem *base_address;
	spinlock_t register_lock;
	struct user_mem mem[USER_MEM];
	unsigned int irq;
	struct kernfs_node *int_nodes[16];
};

struct fpga_flag_attribute {
	struct device_attribute attr;
	unsigned long offset;
	u32 mask;
	u32 shift;
	u32 width;
	u32 max;
};

#define to_fpga_flag(x) container_of(x, struct fpga_flag_attribute, attr)

ssize_t fpga_flag_show(struct device *dev, struct device_attribute *attr,
		char *buf)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	u32 value = in_be32(edev->base_address + eflag->offset);

	value &= eflag->mask;
	value >>= eflag->shift;

	return snprintf(buf, PAGE_SIZE, "%lu\n", (unsigned long)value);
}

ssize_t fpga_flag_store(struct device *dev, struct device_attribute *attr,
		const char *buf, size_t size)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	u32 new = 0;
	u32 val;
	if (kstrtou32(buf, 0, &new))
		return -EINVAL;
	if (eflag->max && new > eflag->max)
		return -EINVAL;
	if (new >> eflag->width)
		return -EINVAL;
	spin_lock(&edev->register_lock);
	val = in_be32(edev->base_address + eflag->offset);
	val &= ~eflag->mask;
	val |= new << eflag->shift;
	out_be32(edev->base_address + eflag->offset, val);
	spin_unlock(&edev->register_lock);
	/* Always return full write size even if we didn't consume all */
	return size;
}

ssize_t core_n_show(struct device *dev, struct device_attribute *attr,
		char *buf)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	u32 value = in_be32(edev->base_address + eflag->offset);

	value &= eflag->mask;
	value >>= eflag->shift;

	value = 1 << value;

	return snprintf(buf, PAGE_SIZE, "%lu\n", (unsigned long)value);
}

ssize_t core_n_store(struct device *dev, struct device_attribute *attr,
		const char *buf, size_t size)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	u32 new = 0;
	u32 val;
	if (kstrtou32(buf, 0, &new))
		return -EINVAL;
	if (!(new & 0x1FF8))
		return -EINVAL;
	val = ffs(new);
	if (new >> val)
		return -EINVAL;
	new = val - 1;
	spin_lock(&edev->register_lock);
	val = in_be32(edev->base_address + eflag->offset);
	val &= ~eflag->mask;
	val |= new << eflag->shift;
	out_be32(edev->base_address + eflag->offset, val);
	spin_unlock(&edev->register_lock);
	return size;
}

ssize_t mul_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	u32 value = in_be32(edev->base_address + eflag->offset);

	value >>= eflag->shift;
	value &= 0xFFFF;

	return snprintf(buf, PAGE_SIZE, "%d\n", (s16)value);
}

ssize_t mul_store(struct device *dev, struct device_attribute *attr,
		const char *buf, size_t size)
{
	struct emce_device *edev = dev_get_drvdata(dev);
	struct fpga_flag_attribute *eflag = to_fpga_flag(attr);
	s16 new = 0;
	u32 val;
	if (kstrtos16(buf, 0, &new))
		return -EINVAL;
	spin_lock(&edev->register_lock);
	val = in_be32(edev->base_address + eflag->offset);
	val &= ~eflag->mask;
	val |= (((u32)new) << eflag->shift) & eflag->mask;
	out_be32(edev->base_address + eflag->offset, val);
	spin_unlock(&edev->register_lock);
	return size;
}

ssize_t dummy_show(struct device *dev, struct device_attribute *attr,
		char *buf)
{
	return snprintf(buf, PAGE_SIZE, "\n");
}

#define FPGA_FLAGC(_base, _name, _mode, _offset, _bit, _width, _max, _show, \
		_store) \
	struct fpga_flag_attribute dev_attr_##_base##_##_name = \
		{ __ATTR(_name, _mode, _show, _store),\
		_offset, ((1<<(_width))-1)<<_bit, _bit, _width, _max }
#define FPGA_FLAG(_base, _name, _mode, _offset, _bit, _width) \
	FPGA_FLAGC(_base, _name, _mode, _offset, _bit, _width, 0, \
			fpga_flag_show, fpga_flag_store)
#define FPGA_FLAGM(_base, _name, _mode, _offset, _bit, _width, _max) \
	FPGA_FLAGC(_base, _name, _mode, _offset, _bit, _width, _max, \
			fpga_flag_show, fpga_flag_store)
#define ATTR_INT(name) struct device_attribute dev_attr_int_##name = \
	__ATTR(name, 0440, dummy_show, NULL)

FPGA_FLAG(rec0, enable, 0660, REG0_OFFSET, 0, 1);
FPGA_FLAG(rec0, polarity, 0660, REG0_OFFSET, 1, 1);
FPGA_FLAG(rec0, descramble, 0660, REG0_OFFSET, 2, 1);
FPGA_FLAG(rec0, rxeqmix, 0660, REG0_OFFSET, 3, 2);
FPGA_FLAG(rec0, data_valid, 0440, REG0_OFFSET, 5, 1);
FPGA_FLAG(rec1, enable, 0660, REG0_OFFSET, 8, 1);
FPGA_FLAG(rec1, polarity, 0660, REG0_OFFSET, 9, 1);
FPGA_FLAG(rec1, descramble, 0660, REG0_OFFSET, 10, 1);
FPGA_FLAG(rec1, rxeqmix, 0660, REG0_OFFSET, 11, 2);
FPGA_FLAG(rec1, data_valid, 0440, REG0_OFFSET, 13, 1);
FPGA_FLAG(rec, input_select, 0660, REG0_OFFSET, 24, 1);
FPGA_FLAG(rec, stream_valid, 0440, REG0_OFFSET, 26, 1);
FPGA_FLAG(rec, rst, 0220, REG0_OFFSET, 31, 1);
FPGA_FLAGM(_, depth, 0660, REG1_OFFSET, 0, 16, 49152);
FPGA_FLAG(trig, type, 0660, REG1_OFFSET, 16, 1);
FPGA_FLAG(trig, arm, 0660, REG1_OFFSET, 18, 1);
FPGA_FLAG(trig, int, 0220, REG1_OFFSET, 19, 1);
FPGA_FLAG(trig, rst, 0220, REG1_OFFSET, 23, 1);
FPGA_FLAG(avg, width, 0660, REG1_OFFSET, 24, 2);
FPGA_FLAG(avg, active, 0440, REG1_OFFSET, 26, 1);
FPGA_FLAG(avg, err, 0440, REG1_OFFSET, 27, 1);
FPGA_FLAG(avg, rst, 0220, REG1_OFFSET, 31, 1);
FPGA_FLAG(core, scale_sch0, 0660, REG2_OFFSET, 0, 2);
FPGA_FLAG(core, scale_sch1, 0660, REG2_OFFSET, 2, 2);
FPGA_FLAG(core, scale_sch2, 0660, REG2_OFFSET, 4, 2);
FPGA_FLAG(core, scale_sch3, 0660, REG2_OFFSET, 6, 2);
FPGA_FLAG(core, scale_sch4, 0660, REG2_OFFSET, 8, 2);
FPGA_FLAG(core, scale_sch5, 0660, REG2_OFFSET, 10, 2);
FPGA_FLAG(core, scale_schi0, 0660, REG2_OFFSET, 16, 2);
FPGA_FLAG(core, scale_schi1, 0660, REG2_OFFSET, 18, 2);
FPGA_FLAG(core, scale_schi2, 0660, REG2_OFFSET, 20, 2);
FPGA_FLAG(core, scale_schi3, 0660, REG2_OFFSET, 22, 2);
FPGA_FLAG(core, scale_schi4, 0660, REG2_OFFSET, 24, 2);
FPGA_FLAG(core, scale_schi5, 0660, REG2_OFFSET, 26, 2);
FPGA_FLAGM(core, L, 0660, REG3_OFFSET, 0, 12, 4096);
FPGA_FLAG(core, scale_cmul, 0660, REG3_OFFSET, 14, 2);
FPGA_FLAGC(core, n, 0660, REG3_OFFSET, 16, 5, 0, core_n_show, core_n_store);
FPGA_FLAG(core, iq, 0660, REG3_OFFSET, 24, 1);
FPGA_FLAG(core, start, 0660, REG3_OFFSET, 25, 1);
FPGA_FLAG(core, ov_fft, 0440, REG3_OFFSET, 26, 1);
FPGA_FLAG(core, ov_ifft, 0440, REG3_OFFSET, 27, 1);
FPGA_FLAG(core, ov_cmul, 0440, REG3_OFFSET, 28, 1);
FPGA_FLAG(core, circular, 0660, REG3_OFFSET, 29, 1);
FPGA_FLAG(core, rst, 0220, REG3_OFFSET, 31, 1);
FPGA_FLAGC(tx, muli, 0660, REG4_OFFSET, 0, 16, 0, mul_show, mul_store);
FPGA_FLAGC(tx, mulq, 0660, REG4_OFFSET, 16, 16, 0, mul_show, mul_store);
FPGA_FLAG(tx, frame_offset, 0660, REG5_OFFSET, 0, 16);
FPGA_FLAG(tx, deskew, 0220, REG5_OFFSET, 16, 1);
FPGA_FLAG(tx, dc_balance, 0660, REG5_OFFSET, 17, 1);
FPGA_FLAG(tx, toggle, 0660, REG5_OFFSET, 18, 1);
FPGA_FLAG(tx, resync, 0220, REG5_OFFSET, 19, 1);
FPGA_FLAG(tx, rst, 0220, REG5_OFFSET, 23, 1);
FPGA_FLAG(auto, run, 0660, REG5_OFFSET, 24, 1);
FPGA_FLAG(auto, rst, 0660, REG5_OFFSET, 25, 1);
FPGA_FLAG(tx, sat, 0660, REG5_OFFSET, 28, 1);
FPGA_FLAG(tx, ovfl, 0660, REG5_OFFSET, 29, 1);
FPGA_FLAG(tx, shift, 0660, REG5_OFFSET, 30, 2);
ATTR_INT(rec0_valid);
ATTR_INT(rec0_invalid);
ATTR_INT(rec1_valid);
ATTR_INT(rec1_invalid);
ATTR_INT(stream_valid);
ATTR_INT(stream_invalid);
ATTR_INT(trigd);
ATTR_INT(avg_done);
ATTR_INT(core_done);
ATTR_INT(tx_toggled);
ATTR_INT(tx_ovfl);
ATTR_INT(auto_done);

#define RECEIVER_ATTRS(_num) \
	static struct attribute *receiver_attrs_##_num[] = { \
		&dev_attr_rec##_num##_enable.attr.attr, \
		&dev_attr_rec##_num##_polarity.attr.attr,\
		&dev_attr_rec##_num##_descramble.attr.attr,\
		&dev_attr_rec##_num##_rxeqmix.attr.attr,\
		&dev_attr_rec##_num##_data_valid.attr.attr,\
		NULL,\
	};

RECEIVER_ATTRS(0)
RECEIVER_ATTRS(1)

static struct attribute *rec_attrs[] = {
	&dev_attr_rec_input_select.attr.attr,
	&dev_attr_rec_stream_valid.attr.attr,
	&dev_attr_rec_rst.attr.attr,
	NULL
};

static struct attribute *trig_attrs[] = {
	&dev_attr_trig_type.attr.attr,
	&dev_attr_trig_arm.attr.attr,
	&dev_attr_trig_int.attr.attr,
	&dev_attr_trig_rst.attr.attr,
	NULL
};

static struct attribute *avg_attrs[] = {
	&dev_attr_avg_width.attr.attr,
	&dev_attr_avg_active.attr.attr,
	&dev_attr_avg_err.attr.attr,
	&dev_attr_avg_rst.attr.attr,
	NULL
};

static struct attribute *core_attrs[] = {
	&dev_attr_core_scale_sch0.attr.attr,
	&dev_attr_core_scale_sch1.attr.attr,
	&dev_attr_core_scale_sch2.attr.attr,
	&dev_attr_core_scale_sch3.attr.attr,
	&dev_attr_core_scale_sch4.attr.attr,
	&dev_attr_core_scale_sch5.attr.attr,
	&dev_attr_core_scale_schi0.attr.attr,
	&dev_attr_core_scale_schi1.attr.attr,
	&dev_attr_core_scale_schi2.attr.attr,
	&dev_attr_core_scale_schi3.attr.attr,
	&dev_attr_core_scale_schi4.attr.attr,
	&dev_attr_core_scale_schi5.attr.attr,
	&dev_attr_core_scale_cmul.attr.attr,
	&dev_attr_core_L.attr.attr,
	&dev_attr_core_n.attr.attr,
	&dev_attr_core_iq.attr.attr,
	&dev_attr_core_start.attr.attr,
	&dev_attr_core_ov_fft.attr.attr,
	&dev_attr_core_ov_ifft.attr.attr,
	&dev_attr_core_ov_cmul.attr.attr,
	&dev_attr_core_circular.attr.attr,
	&dev_attr_core_rst.attr.attr,
	NULL
};

static struct attribute *tx_attrs[] = {
	&dev_attr_tx_muli.attr.attr,
	&dev_attr_tx_mulq.attr.attr,
	&dev_attr_tx_frame_offset.attr.attr,
	&dev_attr_tx_deskew.attr.attr,
	&dev_attr_tx_dc_balance.attr.attr,
	&dev_attr_tx_toggle.attr.attr,
	&dev_attr_tx_resync.attr.attr,
	&dev_attr_tx_rst.attr.attr,
	&dev_attr_tx_ovfl.attr.attr,
	&dev_attr_tx_sat.attr.attr,
	&dev_attr_tx_shift.attr.attr,
	NULL
};

static struct attribute *auto_attrs[] = {
	&dev_attr_auto_run.attr.attr,
	&dev_attr_auto_rst.attr.attr,
	NULL
};

static struct attribute *int_attrs[] = {
	&dev_attr_int_rec0_valid.attr,
	&dev_attr_int_rec0_invalid.attr,
	&dev_attr_int_rec1_valid.attr,
	&dev_attr_int_rec1_invalid.attr,
	&dev_attr_int_stream_valid.attr,
	&dev_attr_int_stream_invalid.attr,
	&dev_attr_int_trigd.attr,
	&dev_attr_int_avg_done.attr,
	&dev_attr_int_core_done.attr,
	&dev_attr_int_tx_toggled.attr,
	&dev_attr_int_tx_ovfl.attr,
	&dev_attr_int_auto_done.attr,
	NULL
};

static struct attribute *system_attrs[] = {
	&dev_attr___depth.attr.attr,
	NULL
};

static struct attribute_group groups[] = {
	{
		.name = NULL,
		.attrs = system_attrs,
	},
	{
		.name = "gtx0",
		.attrs = receiver_attrs_0,
	},
	{
		.name = "gtx1",
		.attrs = receiver_attrs_1,
	},
	{
		.name = "receiver",
		.attrs = rec_attrs,
	},
	{
		.name = "trigger",
		.attrs = trig_attrs,
	},
	{
		.name = "average",
		.attrs = avg_attrs,
	},
	{
		.name = "core",
		.attrs = core_attrs,
	},
	{
		.name = "transmitter",
		.attrs = tx_attrs,
	},
	{
		.name = "auto",
		.attrs = auto_attrs,
	},
	{
		.name = "int",
		.attrs = int_attrs,
	},
	{
		.attrs = NULL,
	},
};

static irqreturn_t edev_isr(int irq, void *dev_id)
{
	struct device *dev=(struct device*)dev_id;
	struct emce_device *edev = dev_get_drvdata(dev_id);

	u32 status;
	int i;

	status = in_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET);
	out_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET, status);

	for(i=0; edev->int_nodes[i]; i++)
		if((status >> (15 - i)) & 1)
		{
			sysfs_notify_dirent(edev->int_nodes[i]);
			dev_dbg(dev,"got intr %d %s\n", i, int_attrs[i]->name);
		}

	return IRQ_HANDLED;
}

ssize_t mem_read (struct file *file, char __user *buf,
		size_t count, loff_t *ppos)
{
	struct user_mem *mem = file->private_data;

	if(*ppos >= mem->size)
		return 0; //EOF

	if(*ppos + count >= mem->size)
		count = mem->size - *ppos;

	if(copy_to_user(buf, mem->base_address+*ppos, count))
		return -EFAULT;

	*ppos+=count;
	return count;
}

ssize_t mem_write(struct file *file, const char __user *buf,
		size_t count, loff_t *ppos)
{
	struct user_mem *mem = file->private_data;

	if(*ppos >= mem->size)
		return -EFBIG;

	if(*ppos + count >= mem->size)
		count = mem->size - *ppos;

	if(copy_from_user(mem->base_address+*ppos, buf, count))
		return -EFAULT;

	*ppos+=count;
	return count;
}

static int mem_open(struct inode *inode, struct file *file)
{
	struct emce_device *edev;

	if(MINOR(inode->i_rdev)>=USER_MEM)
		return -ENODEV;

	edev = container_of(inode->i_cdev, struct emce_device, cdev);
	file->private_data = &edev->mem[MINOR(inode->i_rdev)];
	return 0;
}

static loff_t mem_lseek(struct file *file, loff_t offset, int orig)
{
	struct user_mem *mem = file->private_data;

	loff_t ret;

	switch(orig)
	{
	case 0: ret = offset; break;
	case 1: ret = file->f_pos + offset; break;
	case 2: ret = mem->size - offset; break;
	default: return -EINVAL;
	}
	if(ret>mem->size)
		return -EINVAL;
	if(ret<0)
		return -EINVAL;
	file->f_pos = ret;
	return ret;
}

static struct vm_operations_struct mem_mmap_ops = {
};

static int mem_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct user_mem *mem = file->private_data;
	unsigned long off = vma->vm_pgoff << PAGE_SHIFT;
	unsigned long vsize = vma->vm_end - vma->vm_start;
	unsigned long psize = mem->size - off;

	if (vsize > psize)
		return -EINVAL;

	if (io_remap_pfn_range(vma, vma->vm_start,
				mem->start >> PAGE_SHIFT,
				vsize,
				vma->vm_page_prot))
		return -EAGAIN;

	vma->vm_ops = &mem_mmap_ops;
	return 0;
}

static const struct file_operations emce_fops = {
	.owner = THIS_MODULE,
	.read = mem_read,
	.write = mem_write,
	.open = mem_open,
	.mmap = mem_mmap,
	.llseek = mem_lseek,
};

static struct class *emce_class;

static int emce_of_probe(struct platform_device *ofdev)
{
	struct resource r_mem;
	struct device *dev = &ofdev->dev;
	struct emce_device *edev = NULL;
	struct kernfs_node *intrs = NULL;

	int rc = 0;
	int i;
	int minor;

	edev = kzalloc(sizeof(struct emce_device), GFP_KERNEL);
	if(!edev)
	{
		dev_err(dev, "Couldn't allocate device private record!\n");
		return -ENOMEM;
	}

	rc = of_address_to_resource(dev->of_node, 0, &r_mem);
	if(rc)
	{
		dev_err(dev, "invalid address\n");
		goto error1;
	}
	edev->reg_start = r_mem.start;
	edev->reg_size = r_mem.end - r_mem.start + 1;

	dev_dbg(dev, "got regs @0x%08lx:0x%08lx\n",
			(unsigned long)edev->reg_start,
			(unsigned long)(edev->reg_start+edev->reg_size));
	for(i=0;i<USER_MEM;i++)
	{
		rc = of_address_to_resource(dev->of_node, i+1, &r_mem);
		if(rc)
		{
			dev_err(dev, "invalid address\n");
			goto error1;
		}
		edev->mem[i].start = r_mem.start;
		edev->mem[i].size = r_mem.end - r_mem.start + 1;
		dev_dbg(dev, "got mem%d @0x%08lx:0x%08lx\n", i,
				(unsigned long)edev->mem[i].start,
				(unsigned long)(edev->mem[i].start +
					edev->mem[i].size));
	}

	edev->irq = irq_of_parse_and_map(dev->of_node, 0);
	spin_lock_init(&edev->register_lock);

	dev_set_drvdata(dev, (void *)edev);

	if(!request_mem_region(edev->reg_start, edev->reg_size,
				DRIVER_NAME))
	{
		dev_err(dev, "Couldn't lock memory region at 0x%08lx\n",
				(unsigned long)edev->reg_start);
		rc = -EBUSY;
		goto error1;
	}

	edev->base_address = ioremap(edev->reg_start, edev->reg_size);
	if(edev->base_address == NULL)
	{
		dev_err(dev, "Couldn't ioremap memory at 0x%08lx\n",
				(unsigned long)edev->reg_start);
		rc = -EFAULT;
		goto error2;
	}

	for(i=0;i<USER_MEM;i++)
	{
		if(!request_mem_region(edev->mem[i].start, edev->mem[i].size,
					DRIVER_NAME))
		{
			dev_err(dev, "Couldn't lock memory region at 0x%08lx\n",
					(unsigned long)edev->mem[i].start);
			rc = -EBUSY;
			goto error3;
		}

		edev->mem[i].base_address = ioremap(edev->mem[i].start,
				edev->mem[i].size);
		if(edev->mem[i].base_address == NULL)
		{
			dev_err(dev, "Couldn't ioremap memory at 0x%08lx\n",
					(unsigned long)edev->mem[i].start);
			rc = -EFAULT;
			release_mem_region(edev->mem[i].start,
					edev->mem[i].size);
			goto error3;
		}
	}

	for(i=0; groups[i].attrs; i++)
	{
		if(sysfs_create_group(&dev->kobj, &groups[i]))
		{
			dev_err(dev, "Couldn't create sysfs entries\n");
			rc = -EFAULT;
			goto error4;
		}
	}

	intrs = sysfs_get_dirent(dev->kobj.sd, "int");
	if(!intrs)
	{
		dev_err(dev, "Couldn't locate interrupt directory\n");
		rc = -EFAULT;
		goto error4;
	}
	for(i=0; int_attrs[i]; i++)
	{
		edev->int_nodes[i] = sysfs_get_dirent(intrs,
				int_attrs[i]->name);
		if(!edev->int_nodes[i]) {
			dev_err(dev, "Couldn't locate interrupt %s\n",
					int_attrs[i]->name);
			rc = -EFAULT;
			goto error5;
		}
	}
	sysfs_put(intrs);
	for(; i<16; i++)
	{
		edev->int_nodes[i] = NULL;
	}

	if(request_irq(edev->irq, edev_isr, IRQF_SHARED, DRIVER_NAME, dev))
	{
		dev_err(dev, "Couldn't request IRQ %d\n",edev->irq);
		rc = -EFAULT;
		goto error6;
	}

	if(alloc_chrdev_region(&edev->dev, 0, USER_MEM, DRIVER_NAME))
	{
		dev_err(dev, "Couldn't alloc char devs\n");
		rc = -EFAULT;
		goto error7;
	}

	cdev_init(&edev->cdev, &emce_fops);
	edev->cdev.owner = THIS_MODULE;
	kobject_set_name(&edev->cdev.kobj, "mem");
	if(cdev_add(&edev->cdev, edev->dev, USER_MEM))
	{
		dev_err(dev, "Couldn't create char devs\n");
		rc = -EFAULT;
		goto error8;
	}

	emce_class = class_create(THIS_MODULE, DRIVER_NAME);
	if(IS_ERR(emce_class))
		goto error8;

	for(minor = 0; minor < USER_MEM; minor++)
		device_create(emce_class, dev, MKDEV(MAJOR(edev->dev), minor),
				NULL, "emce%d", minor);

	dev_dbg(dev, "Registered char dev %d:%d - %d:%d\n", MAJOR(edev->dev),
			MINOR(edev->dev), MAJOR(edev->dev),
			MINOR(edev->dev)+USER_MEM-1);

	//Reset Hardware
	out_be32(edev->base_address + EMCE_RST_REG_OFFSET, EMCE_SOFT_RESET);
	//Enable interrupts from user logic
	out_be32(edev->base_address + EMCE_INTR_IPIER_OFFSET, 0xFFFFFFFF);
	//Enable user logic interrupt source
	out_be32(edev->base_address + EMCE_INTR_DIER_OFFSET,
			EMCE_INTR_IPIR_MASK);
	//Global interrupt enable
	out_be32(edev->base_address + EMCE_INTR_DGIER_OFFSET,
			EMCE_INTR_GIE_MASK);

	return 0;
error8:
	unregister_chrdev_region(edev->dev, USER_MEM);
error7:
	free_irq(edev->irq, dev);
	for(i=0; int_attrs[i]; i++);
error6:
	for(i--; i>0; i--)
	{
		sysfs_put(edev->int_nodes[i]);
	}
	sysfs_put(intrs);
	for(i=0; groups[i].attrs; i++);
error5:
	for(i--; i>0; i--)
	{
		sysfs_remove_group(&dev->kobj, &groups[i]);
	}
error4:
	for(i=0;i<USER_MEM;i++)
	{
		if(edev->mem[i].base_address!=NULL)
		{
			iounmap(edev->mem[i].base_address);
			release_mem_region(edev->mem[i].start,
					edev->mem[i].size);
		}
	}
error3:
	iounmap(edev->base_address);
error2:
	release_mem_region(edev->reg_start, edev->reg_size);
error1:
	kfree(edev);

	return rc;
}

static int emce_of_remove(struct platform_device *of_dev)
{
	struct device *dev = &of_dev->dev;
	struct emce_device *edev = dev_get_drvdata(dev);

	int i;
	int minor;

	//Reset Hardware (this also disables interrupts)
	out_be32(edev->base_address + EMCE_RST_REG_OFFSET, EMCE_SOFT_RESET);

	//unregister stuff
	cdev_del(&edev->cdev);
	unregister_chrdev_region(edev->dev, USER_MEM);
	for(minor = 0; minor < USER_MEM; minor++)
		device_destroy(emce_class, MKDEV(MAJOR(edev->dev),minor));
	class_destroy(emce_class);
	free_irq(edev->irq, dev);
	for(i=0; int_attrs[i]; i++)
	{
		sysfs_put(edev->int_nodes[i]);
	}
	for(i=0; groups[i].attrs; i++)
	{
		sysfs_remove_group(&dev->kobj, &groups[i]);
	}
	for(i=0;i<USER_MEM;i++)
	{
		if(edev->mem[i].base_address!=NULL)
		{
			iounmap(edev->mem[i].base_address);
			release_mem_region(edev->mem[i].start,
					edev->mem[i].size);
		}
	}
	iounmap(edev->base_address);
	release_mem_region(edev->reg_start, edev->reg_size);
	kfree(edev);
	dev_set_drvdata(dev, NULL);

	return 0;
}

static const struct of_device_id emce_of_match[] = {
	{ .compatible = "xlnx,proc2fpga-3.00.b", },
	{ /* end of list */ },
};

MODULE_DEVICE_TABLE(of, emce_of_match);

static struct platform_driver emce_of_driver = {
	.driver = {
		.name = DRIVER_NAME,
		.owner = THIS_MODULE,
		.of_match_table = emce_of_match,
	},
	.probe = emce_of_probe,
	.remove = emce_of_remove,
};

module_platform_driver(emce_of_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Gernot Vormayr <notti@fet.at");
MODULE_DESCRIPTION("driver for custom fpga interface");

