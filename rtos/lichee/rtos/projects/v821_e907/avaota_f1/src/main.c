/*
 * Copyright (c) 2019-2025 Allwinner Technology Co., Ltd. ALL rights reserved.
 *
 * Allwinner is a trademark of Allwinner Technology Co.,Ltd., registered in
 * the people's Republic of China and other countries.
 * All Allwinner Technology Co.,Ltd. trademarks are used with permission.
 *
 * DISCLAIMER
 * THIRD PARTY LICENCES MAY BE REQUIRED TO IMPLEMENT THE SOLUTION/PRODUCT.
 * IF YOU NEED TO INTEGRATE THIRD PARTY’S TECHNOLOGY (SONY, DTS, DOLBY, AVS OR MPEGLA, ETC.)
 * IN ALLWINNERS’SDK OR PRODUCTS, YOU SHALL BE SOLELY RESPONSIBLE TO OBTAIN
 * ALL APPROPRIATELY REQUIRED THIRD PARTY LICENCES.
 * ALLWINNER SHALL HAVE NO WARRANTY, INDEMNITY OR OTHER OBLIGATIONS WITH RESPECT TO MATTERS
 * COVERED UNDER ANY REQUIRED THIRD PARTY LICENSE.
 * YOU ARE SOLELY RESPONSIBLE FOR YOUR USAGE OF THIRD PARTY’S TECHNOLOGY.
 *
 *
 * THIS SOFTWARE IS PROVIDED BY ALLWINNER"AS IS" AND TO THE MAXIMUM EXTENT
 * PERMITTED BY LAW, ALLWINNER EXPRESSLY DISCLAIMS ALL WARRANTIES OF ANY KIND,
 * WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING WITHOUT LIMITATION REGARDING
 * THE TITLE, NON-INFRINGEMENT, ACCURACY, CONDITION, COMPLETENESS, PERFORMANCE
 * OR MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 * IN NO EVENT SHALL ALLWINNER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS, OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include "interrupt.h"
#include <portmacro.h>
#include "FreeRTOS.h"
#include "task.h"
#include <hal_time.h>

#include <console.h>

#ifdef CONFIG_DRIVERS_MSGBOX
#include <hal_msgbox.h>
#endif

#if defined(CONFIG_INIT_NET_STACK) || defined(CONFIG_DRIVERS_V821_USE_SIP_WIFI) || \
    defined(CONFIG_XRADIO_BT_CONTROLLER)
#include "drv/xr_coex/xr_coex.h"
#endif

#ifdef CONFIG_COMPONENTS_PM
extern int pm_init(int argc, char **argv);
#endif

#ifdef CONFIG_GEN_DIGEST
/* format: 4bytes image size + 16bytes digest */
__attribute__((section(".digest"))) const unsigned char digest_data[20];
#endif

#ifdef CONFIG_COMPONENTS_OPENAMP
#include <openamp/sunxi_helper/rpmsg_master.h>
#include <openamp/sunxi_helper/openamp.h>

#ifdef CONFIG_COMPONENTS_RPBUF
extern int rpbuf_init(void);
#endif

void init_amp_app(void)
{
#ifdef CONFIG_COMPONENTS_AMP_USER_RESOURCE
	extern void show_all_user_resource(void);
	show_all_user_resource();
#endif

#ifdef CONFIG_RPMSG_CLIENT
	rpmsg_ctrldev_create();
#endif

#ifdef CONFIG_RPMSG_HEARBEAT
	extern int rpmsg_heart_init(void);
	rpmsg_heart_init();
#endif

#ifdef CONFIG_MULTI_CONSOLE
	extern int multiple_console_init(void);
	multiple_console_init();
#endif

#ifdef CONFIG_COMPONENTS_RPBUF
	rpbuf_init();
#endif
}

void deinit_amp_app(void)
{
#ifdef CONFIG_COMPONENTS_RPBUF
	extern void rpbuf_deinit(int rproc_id);
	rpbuf_deinit(0);
#endif

#ifdef CONFIG_MULTI_CONSOLE
	extern int multiple_console_deinit(void);
	multiple_console_deinit();
#endif

#ifdef CONFIG_RPMSG_HEARBEAT
	extern int rpmsg_heart_deinit(void);
	rpmsg_heart_deinit();
#endif

#ifdef CONFIG_RPMSG_CLIENT
	rpmsg_ctrldev_release();
#endif

#ifdef CONFIG_RPMSG_NOTIFY
	extern int rpmsg_notify_deinit(void);
	rpmsg_notify_deinit();
#endif
}

void init_amp_framework(void)
{
#if defined(CONFIG_ARCH_RISCV_PMP) && !defined(CONFIG_PMP_EARLY_ENABLE)
	__attribute__((__unused__)) int pmp_ret;

#ifdef CONFIG_COMPONENTS_RPBUF
	extern int set_pmp_for_rpbuf_reserved_mem(void);
	pmp_ret = set_pmp_for_rpbuf_reserved_mem();
	if (pmp_ret)
	{
		printf("set PMP for rpbuf reserved mem faild, ret: %d\n", pmp_ret);
	}
#endif

#endif

	openamp_init();
}

void deinit_amp_framework(void)
{
	openamp_deinit();
}

void openamp_init_thread(void *param)
{
	(void)param;
	init_amp_framework();
	init_amp_app();

#ifdef CONFIG_INIT_NET_STACK
	extern int xradio_link_init(int pm_flag);
	xradio_link_init(0);
#endif
#ifdef CONFIG_DRIVERS_V821_USE_SIP_WIFI
	extern int xradio_rpmsg_create(void);
	xradio_rpmsg_create();
#endif
#ifdef CONFIG_DRIVERS_BLUETOOTH_XRADIO
	extern int bt_xradio_link_init(void);
	bt_xradio_link_init();
#endif
	hal_thread_stop(NULL);
}

void pm_openamp_init_thread(void *param)
{
	(void)param;
	init_amp_framework();
	init_amp_app();

#ifdef CONFIG_INIT_NET_STACK
	extern int xradio_link_init(int pm_flag);
	xradio_link_init(1);
#endif

	hal_thread_stop(NULL);
}


void openamp_deinit_thread(void *param)
{
	(void)param;

	deinit_amp_app();
	deinit_amp_framework();

	hal_thread_stop(NULL);
}

int init_openamp(void)
{
	void *thread;
	thread = hal_thread_create(pm_openamp_init_thread, NULL,
							   "amp_init", 8 * 1024, HAL_THREAD_PRIORITY_SYS);
	if (thread != NULL)
		hal_thread_start(thread);
	else
		return -1;

	return 0;
}

int deinit_openamp(void)
{
	void *thread;
	thread = hal_thread_create(openamp_deinit_thread, NULL,
							   "amp_deinit", 4 * 1024, HAL_THREAD_PRIORITY_SYS);
	if (thread != NULL)
		hal_thread_start(thread);
	else
		return -1;

	return 0;
}

int deinit_openamp_sync(void)
{
#ifdef CONFIG_DRIVERS_V821_USE_SIP_WIFI
	/* todo: implement this function */
	//xradio_rpmsg_relaese();
#endif

#ifdef CONFIG_INIT_NET_STACK
	extern void xradio_link_deinit(void);
//	xradio_link_deinit();
#endif
	deinit_amp_app();
	deinit_amp_framework();

	return 0;
}
#endif


#ifdef CONFIG_COMMAND_AUTO_START_MEMTESTER
static void auto_memtester_thread(void *param)
{
	extern int cmd_memtest();
	cmd_memtest();
	hal_thread_stop(NULL);
}
#endif

#ifdef CONFIG_COMPONENTS_TCPIP
extern void cmd_tcpip_init(void);
#endif

void cpu0_app_entry(void *param)
{
	(void)param;

#ifdef CONFIG_COMPONENTS_PM
	pm_init(1, NULL);
#endif

#ifdef CONFIG_COMPONENTS_OPENAMP
	void *thread;
	thread = hal_thread_create(openamp_init_thread, NULL,
							   "amp_init", 8 * 1024, HAL_THREAD_PRIORITY_SYS);
	if (thread != NULL)
		hal_thread_start(thread);
#endif

#ifdef CONFIG_COMPONENTS_TCPIP
	//tcpip stack init
	cmd_tcpip_init();
#endif

#if defined(CONFIG_INIT_NET_STACK) || defined(CONFIG_DRIVERS_V821_USE_SIP_WIFI) || \
    defined(CONFIG_XRADIO_BT_CONTROLLER)
	xr_coex_init();
#endif

#if defined(CONFIG_COMPONENT_CLI) && !defined(CONFIG_UART_MULTI_CONSOLE_AS_MAIN)
	vCommandConsoleStart(0x1000, HAL_THREAD_PRIORITY_CLI, NULL);
#endif

#ifdef CONFIG_COMMAND_AUTO_START_MEMTESTER
	void *autotest_thread;
	autotest_thread = hal_thread_create(auto_memtester_thread, NULL,
			"auto_memtester", 8 * 1024, HAL_THREAD_PRIORITY_SYS);

	if (autotest_thread != NULL)
		hal_thread_start(autotest_thread);
#endif

	vTaskDelete(NULL);
}
