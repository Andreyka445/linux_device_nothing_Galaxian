#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/backlight.h>
#include <linux/platform_device.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

#define BRIGHTNESSID_PATH "/sys/devices/platform/display_id/brightnessid"
#define MAX_BRIGHTNESS 4095
#define DEFAULT_BRIGHTNESS 2600

static struct backlight_device *galaxian_bd;
static struct platform_device *galaxian_pdev;

static int galaxian_bl_update_status(struct backlight_device *bd)
{
    int brightness = bd->props.brightness;
    struct file *file;
    char buf[16];
    int len;
    loff_t pos = 0;

    if (bd->props.power != FB_BLANK_UNBLANK ||
        bd->props.fb_blank != FB_BLANK_UNBLANK ||
        bd->props.state & BL_CORE_FBBLANK)
        brightness = 0;

    len = snprintf(buf, sizeof(buf), "%d\n", brightness);

    file = filp_open(BRIGHTNESSID_PATH, O_WRONLY, 0);
    if (!IS_ERR(file)) {
        kernel_write(file, buf, len, &pos);
        filp_close(file, NULL);
    }

    return 0;
}

static int galaxian_bl_get_brightness(struct backlight_device *bd)
{
    return bd->props.brightness;
}

static const struct backlight_ops galaxian_bl_ops = {
    .options = BL_CORE_SUSPENDRESUME,
    .update_status = galaxian_bl_update_status,
    .get_brightness = galaxian_bl_get_brightness,
};

static int __init galaxian_bl_init(void)
{
    struct backlight_properties props;

    memset(&props, 0, sizeof(props));
    props.type = BACKLIGHT_RAW;
    props.max_brightness = MAX_BRIGHTNESS;
    props.brightness = DEFAULT_BRIGHTNESS;

    galaxian_pdev = platform_device_register_simple("galaxian_backlight", -1, NULL, 0);
    if (IS_ERR(galaxian_pdev))
        return PTR_ERR(galaxian_pdev);

    galaxian_bd = backlight_device_register("panel",
                                           &galaxian_pdev->dev,
                                           NULL,
                                           &galaxian_bl_ops,
                                           &props);
    if (IS_ERR(galaxian_bd)) {
        platform_device_unregister(galaxian_pdev);
        return PTR_ERR(galaxian_bd);
    }

    backlight_update_status(galaxian_bd);
    pr_info("galaxian_backlight: Registered /sys/class/backlight/panel successfully!\n");
    return 0;
}

static void __exit galaxian_bl_exit(void)
{
    if (galaxian_bd)
        backlight_device_unregister(galaxian_bd);
    if (galaxian_pdev)
        platform_device_unregister(galaxian_pdev);
    pr_info("galaxian_backlight: Unregistered\n");
}

module_init(galaxian_bl_init);
module_exit(galaxian_bl_exit);

MODULE_AUTHOR("CoolBoy1337");
MODULE_DESCRIPTION("Backlight bridge driver for Nothing Phone (2a) Galaxian");
MODULE_LICENSE("GPL");
