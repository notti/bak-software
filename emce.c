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
#include <asm/uaccess.h>

#define DRIVER_NAME "emce"
#define USER_MEM 3

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

static ssize_t led_show(struct device *dev, struct device_attribute *attr,
        char *buf)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u8 val;
    unsigned int led = 0;
    sscanf(attr->attr.name, "%d",&led);
    led = 7-led;

    val = in_8(edev->base_address+3);
    if(val & (1<<led))
        return sprintf(buf,"1");
    return sprintf(buf,"0");
}

static ssize_t led_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u8 val;
    unsigned int led = 0;
    sscanf(attr->attr.name,"%u",&led);
    led=7-led;

    spin_lock(&edev->register_lock);
    val = in_8(edev->base_address+3);
    if(buf[0] == '1')
        val|=1<<led;
    else
        val&=~(1<<led);
    out_8(edev->base_address+3,val);
    spin_unlock(&edev->register_lock);

    return count;
}

static DEVICE_ATTR(0, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(1, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(2, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(3, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(4, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(5, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(6, (S_IRUGO|S_IWUGO), led_show, led_store);
static DEVICE_ATTR(7, (S_IRUGO|S_IWUGO), led_show, led_store);


static struct attribute *leds_attrs[] = {
    &dev_attr_0.attr,
    &dev_attr_1.attr,
    &dev_attr_2.attr,
    &dev_attr_3.attr,
    &dev_attr_4.attr,
    &dev_attr_5.attr,
    &dev_attr_6.attr,
    &dev_attr_7.attr,
    NULL,
};

static struct attribute_group leds_group = {
    .attrs = leds_attrs,
    .name = "leds",
};

static ssize_t register_show(struct device *dev, struct device_attribute *attr,
        char *buf)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    u32 val;
    unsigned int num=0;
    sscanf(attr->attr.name, "reg%d",&num);

    val = in_be32(edev->base_address + num*4);
    return sprintf(buf,"0x%x",val);
}

static ssize_t register_store(struct device *dev, struct device_attribute *attr,
        const char *buf, size_t count)
{
    struct emce_device *edev = dev_get_drvdata(dev);
    unsigned long val;
    unsigned int num=0;
    sscanf(attr->attr.name, "reg%d",&num);

    sscanf(buf,"%lx",&val);

    out_be32(edev->base_address + num*4,val);
    return count;
}

static DEVICE_ATTR(reg0, (S_IRUGO|S_IWUGO), register_show, register_store);
static DEVICE_ATTR(reg1, (S_IRUGO|S_IWUGO), register_show, register_store);

static ssize_t intr_show(struct device *dev, struct device_attribute *attr,
        char *buf)
{
    return sprintf(buf,"1");
}

static DEVICE_ATTR(intr, S_IRUGO, intr_show, NULL);

static struct attribute *register_attrs[] = {
    &dev_attr_reg0.attr,
    &dev_attr_reg1.attr,
    &dev_attr_intr.attr,
    NULL
};

static struct attribute_group register_group = {
    .attrs = register_attrs,
};

static irqreturn_t edev_isr(int irq, void *dev_id)
{
    struct device *dev=(struct device*)dev_id;
    struct emce_device *edev = dev_get_drvdata(dev_id);

    u32 status;

    status = in_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET);
    out_be32(edev->base_address + EMCE_INTR_IPISR_OFFSET, status);

    sysfs_notify(&dev->kobj, NULL, "intr");

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

static const struct file_operations emce_fops = {
    .owner = THIS_MODULE,
    .read = mem_read,
    .write = mem_write,
    .open = mem_open,
    .llseek = mem_lseek,
};

static int __devinit emce_of_probe(struct platform_device *ofdev,
        const struct of_device_id *match)
{
    struct resource r_mem;
    struct device *dev = &ofdev->dev;
    struct emce_device *edev = NULL;

    int rc = 0;
    int i;

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

    dev_info(dev, "got regs @0x%08lx:0x%08lx\n",
            (unsigned long)edev->reg_start,
            (unsigned long)edev->reg_size);
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
        dev_info(dev, "got mem%d @0x%08lx:0x%08lx\n", i,
                (unsigned long)edev->mem[i].start,
                (unsigned long)edev->mem[i].size);
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

        edev->mem[i].base_address = ioremap(edev->mem[i].start, edev->mem[i].size);
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

    if(sysfs_create_group(&dev->kobj, &leds_group))
    {
        dev_err(dev, "Couldn't create sysfs entries\n");
        rc = -EFAULT;
        goto error5;
    }

    if(sysfs_create_group(&dev->kobj, &register_group))
    {
        dev_err(dev, "Couldn't create sysfs entries\n");
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

    dev_info(dev, "Registered char dev %d:%d - %d:%d\n", MAJOR(edev->dev),
            MINOR(edev->dev), MAJOR(edev->dev), MINOR(edev->dev)+USER_MEM-1);

    //Reset Hardware
    out_be32(edev->base_address + EMCE_RST_REG_OFFSET, EMCE_SOFT_RESET);
    //Enable interrupts from user logic
    out_be32(edev->base_address + EMCE_INTR_IPIER_OFFSET, 0x00000001);
    //Enable user logic interrupt source
    out_be32(edev->base_address + EMCE_INTR_DIER_OFFSET, EMCE_INTR_IPIR_MASK);
    //Global interrupt enable
    out_be32(edev->base_address + EMCE_INTR_DGIER_OFFSET, EMCE_INTR_GIE_MASK);

    return 0;
error8:
    unregister_chrdev_region(edev->dev, USER_MEM);
error7:
    sysfs_remove_group(&dev->kobj, &register_group);
error6:
    sysfs_remove_group(&dev->kobj, &leds_group);
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
    
    //Reset Hardware (this also disables interrupts)
    out_be32(edev->base_address + EMCE_RST_REG_OFFSET, EMCE_SOFT_RESET);

    //unregister stuff
    cdev_del(&edev->cdev);
    unregister_chrdev_region(edev->dev, USER_MEM);
    sysfs_remove_group(&dev->kobj, &register_group);
    sysfs_remove_group(&dev->kobj, &leds_group);
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
    { .compatible = "xlnx,proc2fpga-1.00.a", },
    { /* end of list */ },
};

static struct of_platform_driver emce_of_driver = {
    .driver = {
        .name        = DRIVER_NAME,
        .owner       = THIS_MODULE,
        .of_match_table = emce_of_match,
    },
    .probe       = emce_of_probe,
    .remove      = __devexit_p(emce_of_remove),
};

static int emce_init(void)
{
    return of_register_platform_driver(&emce_of_driver);
}

static void emce_exit(void)
{
    return of_unregister_platform_driver(&emce_of_driver);
}

module_init(emce_init);
module_exit(emce_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Gernot Vormayr <notti@fet.at");

