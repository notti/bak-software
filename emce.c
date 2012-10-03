#define DEBUG

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/device.h>
#include <linux/of_device.h>
#include <linux/of_platform.h>
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
};

#define FLAG(_base, _name, _offset, _acc, _bit, _len) \
static ssize_t _base##_##_name##_show(struct device *dev, \
        struct device_attribute *attr, char *buf) \
{ \
    struct emce_device *edev = dev_get_drvdata(dev); \
    u8 val = in_8(edev->base_address+_offset) >> _bit; \
    return snprintf(buf,PAGE_SIZE,"%hhu\n",val & ((1<<(_len))-1)); \
}\
\
static ssize_t _base##_##_name##_store(struct device *dev, \
        struct device_attribute *attr, const char *buf, size_t count)\
{\
    struct emce_device *edev = dev_get_drvdata(dev);\
    u8 val;\
    u8 valnew = 0;\
    sscanf(buf,"%hhu",&valnew);\
    if(valnew>>_len)\
        return -EINVAL;\
    spin_lock(&edev->register_lock);\
    val = in_8(edev->base_address+_offset);\
    val &= ~(((1<<(_len))-1) << _bit);\
    val |= valnew << _bit;\
    out_8(edev->base_address+_offset,val);\
    spin_unlock(&edev->register_lock);\
    return count;\
}\
\
struct device_attribute dev_attr_##_base##_##_name = \
    __ATTR(_name, _acc, _base##_##_name##_show, _base##_##_name##_store);

#define RECEIVERS 3
#define __RECEIVER(_name, _num, _acc, _bit, _len) \
    FLAG(rec, _name##_##_num, RECEIVERS-_num, _acc, _bit, _len)

#define RECEIVER(_name, _acc, _bit, _len) \
__RECEIVER(_name, 0, _acc, _bit, _len)\
__RECEIVER(_name, 1, _acc, _bit, _len)\
__RECEIVER(_name, 2, _acc, _bit, _len)

RECEIVER(enable, (S_IRUGO|S_IWUGO), 0, 1)
RECEIVER(polarity, (S_IRUGO|S_IWUGO), 1, 1)
RECEIVER(descramble, (S_IRUGO|S_IWUGO), 2, 1)
RECEIVER(rxeqmix, (S_IRUGO|S_IWUGO), 3, 2)
RECEIVER(data_valid, S_IRUGO, 5, 1)

#define RECEIVER_ATTRS(_num) \
static struct attribute *receiver_attrs_##_num[] = { \
    &dev_attr_rec_enable_##_num.attr, \
    &dev_attr_rec_polarity_##_num.attr,\
    &dev_attr_rec_descramble_##_num.attr,\
    &dev_attr_rec_rxeqmix_##_num.attr,\
    &dev_attr_rec_data_valid_##_num.attr,\
    NULL,\
};

RECEIVER_ATTRS(0)
RECEIVER_ATTRS(1)
RECEIVER_ATTRS(2)

FLAG(rec, input_select, 0, (S_IRUGO|S_IWUGO), 0, 2)
FLAG(rec, stream_valid, 0, S_IRUGO, 2, 1)
FLAG(rec, rst, 0, S_IWUGO, 7, 1)

static ssize_t depth_show(struct device *dev, struct device_attribute *attr, 
        char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    u16 val = in_be16(edev->base_address+6);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t depth_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    if(valnew > 50000)
        return -EINVAL;
    out_be16(edev->base_address+6,valnew);

    return count;
}
struct device_attribute dev_attr_depth =
    __ATTR(depth, (S_IRUGO|S_IWUGO), depth_show, depth_store);

FLAG(trig, type, 5, (S_IRUGO|S_IWUGO), 0, 1)
FLAG(trig, arm, 5, (S_IRUGO|S_IWUGO), 2, 1)
FLAG(trig, int, 5, S_IWUGO, 3, 1)
FLAG(trig, rst, 5, S_IWUGO, 7, 1)

FLAG(avg, width, 4, (S_IRUGO|S_IWUGO), 0, 2)
FLAG(avg, active, 4, S_IRUGO, 2, 1)
FLAG(avg, err, 4, S_IRUGO, 3, 1)
FLAG(avg, rst, 4, S_IWUGO, 7, 1)

//TODO
static ssize_t core_scale_sch_show(struct device *dev,
        struct device_attribute *attr, char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    //FIXME
    u16 val = in_be16(edev->base_address+10);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t core_scale_sch_store(struct device *dev,
        struct device_attribute *attr, const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    //FIXME
    out_be16(edev->base_address+10,valnew);

    return count;
}
struct device_attribute dev_attr_core_scale_sch = 
    __ATTR(scale_sch, (S_IRUGO|S_IWUGO), core_scale_sch_show, 
            core_scale_sch_store);

static ssize_t core_scale_schi_show(struct device *dev, 
        struct device_attribute *attr, char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    //FIXME
    u16 val = in_be16(edev->base_address+8);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t core_scale_schi_store(struct device *dev,
        struct device_attribute *attr, const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    //FIXME
    out_be16(edev->base_address+8,valnew);

    return count;
}
struct device_attribute dev_attr_core_scale_schi = 
    __ATTR(scale_schi, (S_IRUGO|S_IWUGO), core_scale_schi_show,
            core_scale_schi_store);

static ssize_t core_L_show(struct device *dev, struct device_attribute *attr, 
        char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    //FIXME
    u16 val = in_be16(edev->base_address+14);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t core_L_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    //FIXME
    out_be16(edev->base_address+14,valnew);

    return count;
}
struct device_attribute dev_attr_core_L = 
    __ATTR(L, (S_IRUGO|S_IWUGO), core_L_show, core_L_store);

FLAG(core, cmul_sch, 14, (S_IRUGO|S_IWUGO), 6, 2)
FLAG(core, n, 13, (S_IRUGO|S_IWUGO), 0, 5) //FIXME
FLAG(core, iq, 12, (S_IRUGO|S_IWUGO), 0, 1)
FLAG(core, start, 12, (S_IRUGO|S_IWUGO), 1, 1)
FLAG(core, ov_fft, 12, S_IRUGO, 2, 1)
FLAG(core, ov_ifft, 12, S_IRUGO, 3, 1)
FLAG(core, ov_cmul, 12, S_IRUGO, 4, 1)
FLAG(core, rst, 12, S_IWUGO, 7, 1)


static ssize_t tx_muli_show(struct device *dev, struct device_attribute *attr, 
        char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    u16 val = in_be16(edev->base_address+18);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t tx_muli_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    out_be16(edev->base_address+18,valnew);

    return count;
}
struct device_attribute dev_attr_tx_muli = 
    __ATTR(muli, (S_IRUGO|S_IWUGO), tx_muli_show, tx_muli_store);

static ssize_t tx_mulq_show(struct device *dev, struct device_attribute *attr, 
        char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    u16 val = in_be16(edev->base_address+16);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t tx_mulq_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    out_be16(edev->base_address+16,valnew);

    return count;
}
struct device_attribute dev_attr_tx_mulq = 
    __ATTR(mulq, (S_IRUGO|S_IWUGO), tx_mulq_show, tx_mulq_store);

static ssize_t tx_frame_offset_show(struct device *dev, struct device_attribute *attr, 
        char *buf) 
{ 
    struct emce_device *edev = dev_get_drvdata(dev); 
    u16 val = in_be16(edev->base_address+22);
    return snprintf(buf,PAGE_SIZE,"%hu\n",val); 
}

static ssize_t tx_frame_offset_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u16 valnew = 0;
    sscanf(buf,"%hu",&valnew);
    out_be16(edev->base_address+22,valnew);

    return count;
}
struct device_attribute dev_attr_tx_frame_offset = 
    __ATTR(frame_offset, (S_IRUGO|S_IWUGO), tx_frame_offset_show, tx_frame_offset_store);

FLAG(tx, deskew, 21, S_IWUGO, 0, 1)
FLAG(tx, dc_balance, 21, (S_IRUGO|S_IWUGO), 1, 1)
FLAG(tx, toggle, 21, (S_IRUGO|S_IWUGO), 2, 1)
FLAG(tx, resync, 21, S_IWUGO, 3, 1)
FLAG(tx, rst, 21, S_IWUGO, 7, 1)

FLAG(mem, req, 20, (S_IRUGO|S_IWUGO), 0, 1)

static struct attribute *rec_attrs[] = {
    &dev_attr_rec_input_select.attr,
    &dev_attr_rec_stream_valid.attr,
    &dev_attr_rec_rst.attr,
    NULL
};

static struct attribute *trig_attrs[] = {
    &dev_attr_trig_type.attr,
    &dev_attr_trig_arm.attr,
    &dev_attr_trig_int.attr,
    &dev_attr_trig_rst.attr,
    NULL
};

static struct attribute *avg_attrs[] = {
    &dev_attr_avg_width.attr,
    &dev_attr_avg_active.attr,
    &dev_attr_avg_err.attr,
    &dev_attr_avg_rst.attr,
    NULL
};

static struct attribute *core_attrs[] = {
    &dev_attr_core_scale_sch.attr,
    &dev_attr_core_scale_schi.attr,
    &dev_attr_core_L.attr,
    &dev_attr_core_cmul_sch.attr,
    &dev_attr_core_n.attr,
    &dev_attr_core_iq.attr,
    &dev_attr_core_start.attr,
    &dev_attr_core_ov_fft.attr,
    &dev_attr_core_ov_ifft.attr,
    &dev_attr_core_ov_cmul.attr,
    &dev_attr_core_rst.attr,
    NULL
};

static struct attribute *tx_attrs[] = {
    &dev_attr_tx_muli.attr,
    &dev_attr_tx_mulq.attr,
    &dev_attr_tx_frame_offset.attr,
    &dev_attr_tx_deskew.attr,
    &dev_attr_tx_dc_balance.attr,
    &dev_attr_tx_toggle.attr,
    &dev_attr_tx_resync.attr,
    &dev_attr_tx_rst.attr,
    NULL
};

#define ATTR_INT(name) struct device_attribute dev_attr_int_##name = \
        __ATTR(name, 0, NULL, NULL)
ATTR_INT(rec0_valid);
ATTR_INT(rec0_invalid);
ATTR_INT(rec1_valid);
ATTR_INT(rec1_invalid);
ATTR_INT(rec2_valid);
ATTR_INT(rec2_invalid);
ATTR_INT(rec3_valid);
ATTR_INT(rec3_invalid);
ATTR_INT(stream_valid);
ATTR_INT(stream_invalid);
ATTR_INT(trigd);
ATTR_INT(avg_done);
ATTR_INT(core_done);
ATTR_INT(tx_toggled);
ATTR_INT(tx_ovfl);

static struct attribute *int_attrs[] = {
    &dev_attr_int_rec0_valid.attr,
    &dev_attr_int_rec0_invalid.attr,
    &dev_attr_int_rec1_valid.attr,
    &dev_attr_int_rec1_invalid.attr,
    &dev_attr_int_rec2_valid.attr,
    &dev_attr_int_rec2_invalid.attr,
    &dev_attr_int_stream_valid.attr,
    &dev_attr_int_stream_invalid.attr,
    &dev_attr_int_trigd.attr,
    &dev_attr_int_avg_done.attr,
    &dev_attr_int_core_done.attr,
    &dev_attr_int_tx_toggled.attr,
    &dev_attr_int_tx_ovfl.attr,
    NULL
};

static struct attribute *system_attrs[] = {
    &dev_attr_depth.attr,
    &dev_attr_mem_req.attr,
    NULL
};

static struct attribute_group groups[] = {
    {
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
        .name = "gtx2",
        .attrs = receiver_attrs_2,
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

    status = in_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET);
    out_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET, status);

    dev_dbg(dev,"got intr 0x%x",status);
// sysfs_notify(kobj, dir, attr)
//    sysfs_notify(&dev->kobj, NULL, "intr"); // dir attr TODO

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

static int __devinit emce_of_probe(struct platform_device *ofdev)
{
    struct resource r_mem;
    struct device *dev = &ofdev->dev;
    struct emce_device *edev = NULL;

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
                (unsigned long)(edev->mem[i].start + edev->mem[i].size));
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
            release_mem_region(edev->mem[i].start,edev->mem[i].size);
            goto error3;
        }
    }
    
    if(request_irq(edev->irq, edev_isr,
            IRQF_SHARED | IRQF_SAMPLE_RANDOM, DRIVER_NAME, dev))
    {
        dev_err(dev, "Couldn't request IRQ %d\n",edev->irq);
        rc = -EFAULT;
        goto error4;
    }

   
    for(i=0; groups[i].attrs; i++)
    {
        if(sysfs_create_group(&dev->kobj, &groups[i]))
        {
            dev_err(dev, "Couldn't create sysfs entries\n");
            rc = -EFAULT;
            goto error5;
        }
    }

    if(alloc_chrdev_region(&edev->dev, 0, USER_MEM, DRIVER_NAME))
    {
        dev_err(dev, "Couldn't alloc char devs\n");
        rc = -EFAULT;
        goto error6;
    }

    cdev_init(&edev->cdev, &emce_fops);
    edev->cdev.owner = THIS_MODULE;
    kobject_set_name(&edev->cdev.kobj, "mem");
    if(cdev_add(&edev->cdev, edev->dev, USER_MEM))
    {
        dev_err(dev, "Couldn't create char devs\n");
        rc = -EFAULT;
        goto error7;
    }

    emce_class = class_create(THIS_MODULE, DRIVER_NAME);
    if(IS_ERR(emce_class))
        goto error7;

    for(minor = 0; minor < USER_MEM; minor++)
        device_create(emce_class, dev, MKDEV(MAJOR(edev->dev), minor),
                NULL, "emce%d", minor);

    dev_dbg(dev, "Registered char dev %d:%d - %d:%d\n", MAJOR(edev->dev),
            MINOR(edev->dev), MAJOR(edev->dev), MINOR(edev->dev)+USER_MEM-1);

    //Reset Hardware
    out_be32(edev->base_address + EMCE_RST_REG_OFFSET, EMCE_SOFT_RESET);
    //Enable interrupts from user logic
    out_be32(edev->base_address + EMCE_INTR_IPIER_OFFSET, 0xFFFFFFFF);
    //Enable user logic interrupt source
    out_be32(edev->base_address + EMCE_INTR_DIER_OFFSET, EMCE_INTR_IPIR_MASK);
    //Global interrupt enable
    out_be32(edev->base_address + EMCE_INTR_DGIER_OFFSET, EMCE_INTR_GIE_MASK);

    return 0;
error7:
    unregister_chrdev_region(edev->dev, USER_MEM);
error6:
    for(i--; i>0; i--)
    {
        sysfs_remove_group(&dev->kobj, &groups[i]);
    }
error5:
    free_irq(edev->irq, dev);
error4:
    for(i=0;i<USER_MEM;i++)
    {
        if(edev->mem[i].base_address!=NULL)
        {
            iounmap(edev->mem[i].base_address);
            release_mem_region(edev->mem[i].start,edev->mem[i].size);
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

static int __devexit emce_of_remove(struct platform_device *of_dev)
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
    for(i=0; groups[i].attrs; i++)
    {
        sysfs_remove_group(&dev->kobj, &groups[i]);
    }
    free_irq(edev->irq, dev);
    for(i=0;i<USER_MEM;i++)
    {
        if(edev->mem[i].base_address!=NULL)
        {
            iounmap(edev->mem[i].base_address);
            release_mem_region(edev->mem[i].start,edev->mem[i].size);
        }
    }
    iounmap(edev->base_address);
    release_mem_region(edev->reg_start, edev->reg_size);
    kfree(edev);
    dev_set_drvdata(dev, NULL);

    return 0;
}

static const struct of_device_id emce_of_match[] __devinitdata = {
    { .compatible = "xlnx,proc2fpga-3.00.b", },
    { /* end of list */ },
};

MODULE_DEVICE_TABLE(of, emce_of_match);

static struct platform_driver emce_of_driver = {
    .driver = {
        .name        = DRIVER_NAME,
        .owner       = THIS_MODULE,
        .of_match_table = emce_of_match,
    },
    .probe       = emce_of_probe,
    .remove      = __devexit_p(emce_of_remove),
};

module_platform_driver(emce_of_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Gernot Vormayr <notti@fet.at");
MODULE_DESCRIPTION("driver for custom fpga interface");

