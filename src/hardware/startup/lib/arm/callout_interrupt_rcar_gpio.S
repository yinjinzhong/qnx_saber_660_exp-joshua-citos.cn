/*
* $QNXLicenseC:
 * Copyright 2015, QNX Software Systems.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"). You
 * may not reproduce, modify or distribute this software except in
 * compliance with the License. You may obtain a copy of the License
 * at: http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTIES OF ANY KIND, either express or implied.
 *
 * This file may contain contributions from others, either as
 * contributors under the License or as licensors under other terms.
 * Please review this entire file for other proprietary rights or license
 * notices, as well as the QNX Development Suite License Guide at
 * http://licensing.qnx.com/license-guide/ for other information.
 * $
 */


/*
 * Renesas R-Car GPIO specific interrupt callouts.
 *
 * interrupt_id_* and interrupt_eoi_* are copied and intermixed with other
 * kernel code during initialisation.
 *
 * They do not follow normal calling conventions, and must fall through
 * to the end, rather than attempting to perform a return instruction.
 *
 *
 *	r5 - holds the syspageptr
 *	r6 - holds the intrinfo_entry pointer
 *	r7 - holds the interrupt mask count
 *
 * The interrupt_id_* routine returns the (controller-relative) level in r4
 */

#include "callout.ah"
#include <arm/r-car.h>


/*
 * -----------------------------------------------------------------------
 * Routine to patch callout code
 *
 * On entry:
 *	r0 - physical address of syspage
 *	r1 - virtual  address of syspage
 *	r2 - offset from start of syspage to start of the callout routine
 *	r3 - offset from start of syspage to read/write data used by callout
 * -----------------------------------------------------------------------
 */

interrupt_patch:
	stmdb	sp!, {r4, lr}
	add		r4, r0, r2			// address of callout routine

	/*
	 * Check whether the GPIO is already mapped
	 */
	ldr		r1, [sp, #8]
	ldr		r1, [r1]
	ldr		r0, Lpbase
	cmp		r1, r0
	strne	r1, Lpbase
	ldreq	r0, Lvaddr
	beq		1f

	/*
	 * Map interrupt controller registers
	 */
	mov		r0, #0x100			// size to map
	bl		callout_io_map
	str		r0, Lvaddr

	/*
	 * Patch the callout routine
	 */
1:
	CALLOUT_PATCH	r4, r0, r1, r2, ip
	ldmia	sp!, {r4, pc}

Lpbase:		.word	-1
Lvaddr:		.word	-1

/*
 * -----------------------------------------------------------------------
 * Identify interrupt source.
 *
 * Returns interrupt number in r4
 * -----------------------------------------------------------------------
 */
CALLOUT_START(interrupt_id_rcar_gpio, 0, interrupt_patch)
	/*
	* Get the interrupt controller base address (patched)
	*/
	mov		ip,     #0x000000ff
	orr		ip, ip, #0x0000ff00
	orr		ip, ip, #0x00ff0000
	orr		ip, ip, #0xff000000

	/*
	 * Read pending interrupt status
	 */
	ldr		r0, [ip, #RCAR_GPIO_INTDT]

	clz		r4, r0
	rsbs	r4, r4, #31
	blt		1f

	/*
	 * mask the interrupt
	 */
	mov		r2, #1
	mov		r1, r2, lsl r4
	mvn		r2, r1
	str		r2, [ip, #RCAR_GPIO_INTMSK]

	/*
	 * Clear the interrupt
	 */
	str		r1, [ip, #RCAR_GPIO_INTCLR]
1:
CALLOUT_END(interrupt_id_rcar_gpio)


/*
 * -----------------------------------------------------------------------
 * Acknowledge specified interrupt
 *
 * On entry:
 *	r4 contains the interrupt number
 *	r7 contains the interrupt mask count
 * -----------------------------------------------------------------------
 */
CALLOUT_START(interrupt_eoi_rcar_gpio, 0, interrupt_patch)
	/*
	 * Get the interrupt controller base address (patched)
	 */
	mov		ip,     #0x000000ff
	orr		ip, ip, #0x0000ff00
	orr		ip, ip, #0x00ff0000
	orr		ip, ip, #0xff000000

	/*
	 * Only unmask interrupt if mask count is zero
	 */
	teq		r7, #0
	bne		0f

	mov		r0, #1
	mov		r1, r0, lsl r4
	str		r1, [ip, #RCAR_GPIO_MSKCLR]

0:
CALLOUT_END(interrupt_eoi_rcar_gpio)


/*
 * -----------------------------------------------------------------------
 * Mask specified interrupt
 *
 * On entry:
 *	r0 - syspage_ptr
 *	r1 - interrupt number
 *
 * Returns:
 *	r0 - error status
 * -----------------------------------------------------------------------
 */
CALLOUT_START(interrupt_mask_rcar_gpio, 0, interrupt_patch)
	/*
	 * Get the interrupt controller base address (patched)
	 */
	mov		ip,     #0x000000ff
	orr		ip, ip, #0x0000ff00
	orr		ip, ip, #0x00ff0000
	orr		ip, ip, #0xff000000

	/*
	 * mask the interrupt
	 */
	mov		r0, #1
	mov		r0, r0, lsl r1
	mvn		r0, r0
	str		r0, [ip, #RCAR_GPIO_INTMSK]

	mov		r0, #0
	mov		pc, lr
CALLOUT_END(interrupt_mask_rcar_gpio)


/*
 * -----------------------------------------------------------------------
 * Unmask specified interrupt
 *
 * On entry:
 *	r0 - syspage_ptr
 *	r1 - interrupt number
 *
 * Returns:
 *	r0 - error status
 * -----------------------------------------------------------------------
 */
CALLOUT_START(interrupt_unmask_rcar_gpio, 0, interrupt_patch)
	/*
	 * Get the interrupt controller base address (patched)
	 */
	mov		ip,     #0x000000ff
	orr		ip, ip, #0x0000ff00
	orr		ip, ip, #0x00ff0000
	orr		ip, ip, #0xff000000

	/*
	 * unmask the interrupt
	 */
	mov		r0, #1
	mov		r0, r0, lsl r1
	str		r0, [ip, #RCAR_GPIO_MSKCLR]

	mov		r0, #0
	mov		pc, lr
CALLOUT_END(interrupt_unmask_rcar_gpio)

#ifdef __QNXNTO__
#ifdef __USESRCVERSION
.section .ident, "SM",%progbits,1;
.asciz "$URL: http://svn.ott.qnx.com/product/branches/6.6.0/trunk/hardware/startup/lib/arm/callout_interrupt_rcar_gpio.S $ $Rev: 799372 $";
.previous
#endif
#endif
