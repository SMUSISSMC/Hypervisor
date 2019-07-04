/* rpi2-hyp-boot.S - RRi 2 bootloader for starting in HYP mode  */

/*
 * Copyright (c) 2015 Sergio L. Pascual <slp@sinrega.org>
 * Copyright (c) 2013 Andre Przywara <andre.przywara@linaro.org>
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//
//
//		CAUTION!!!!!!CAUTION!!!!!!CAUTION!!!!!!CAUTION!!!!!!
//		CAUTION!!!!!!CAUTION!!!!!!CAUTION!!!!!!CAUTION!!!!!!
//
//
// NEVER USE the area of 0x100~0x300 !!!!!!!!!!!!!!!
//
//
//	ALWAYS CHECK AFTER COMPILE!!!! IF THE AREA BEING USED!!!!
//
//	OR DIE!DIE!DIE!
//
//
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#define MODE_MASK		0x1f
#define SVC_MODE		0x13
#define HYP_MODE        0x1a
#define T_BIT           0x20
#define F_BIT           0x40
#define I_BIT           0x80
#define A_BIT           0x100


.arch_extension sec
.arch_extension virt

.section .init
.global _start
/* the vector table for secure state and HYP mode */
_start:
	b jmp_loader 	/* reset */
	.word 0 /* undef */
	adr pc, _secure_monitor
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0

/*
 * secure monitor handler
 * U-boot calls this "software interrupt" in start.S
 * This is executed on a "smc" instruction, we use a "smc #0" to switch
 * to non-secure state.
 * We use only r0 and r1 here, due to constraints in the caller.
 */
_secure_monitor:

	mrc	p15, 0, r1, c1, c1, 0		@ read SCR
	bic	r1, r1, #0x4e			@ clear IRQ, FIQ, EA, nET bits
	orr	r1, r1, #0x31			@ enable NS, AW, FW bits
	orr	r1, r1, #0x100			@ allow HVC instruction

	mcr	p15, 0, r1, c1, c1, 0		@ write SCR (with NS bit set)

    mov     r0, #(F_BIT | I_BIT | A_BIT)    @ Set A, I and F

    orr     r0, r0, #HYP_MODE               @ Slot target mode in
    msr     spsr_cxfs, r0                   @ Set full SPSR

	@ Reset CNTVOFF to 0 before leaving monitor mode
	mov	r0, #0
	mcrr	p15, 4, r0, r0, c14		@ Reset CNTVOFF to zero
1:
	movs	pc, lr				@ return to non-secure SVC


switch_to_SVC:
	mov r10, lr
	mrs	r9 , cpsr
	eor	r9, r9, #HYP_MODE
	tst	r9, #MODE_MASK
	bic	r9 , r9 , #MODE_MASK
	orr	r9 , r9 , #(I_BIT | F_BIT | SVC_MODE)
//THUMB(	orr	r9 , r9 , #PSR_T_BIT	)
	bne	111f
	orr	r9, r9, #A_BIT
	adr	lr, (222f)
	msr	spsr_cxsf, r9
//	__MSR_ELR_HYP(14)
	.word	0xE12EF30E
	eret
111:	
	msr	cpsr_c, r9
222:
	mov lr, r10
	bx lr

/*#define __MSR_ELR_HYP(regnum)	__inst_arm_thumb32(			\
	0xE12EF300 | regnum,						\
	0xF3808E30 | (regnum << 16)					\
)
*/
// end of switch_to_SVC
NEVER_USE_100_300_ZZK:
.rept 550
.word 0
.endr

__hyp_stub_install_secondary:
	@ Now install the hypervisor stub:
	
// test HVBAR for ZZK

	mrc	p15, 4, r7, c12, c0, 0	@ get HVBAR
	ldr r5, =0x3afff000
	mrc     p15, 0, r8, c0, c0, 5		@ get cpu id http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDGIJFB.html
	ubfx    r8, r8, #0, #2

	lsl r8, r8, #2

	str r7, [r5, r8]

	add r5, r5, #0x40
	str r7, [r5, r8]

// test HVBAR for ZZK


	mov r5, #0x3a000000
	add r5, r5, #0xf00000
	adrl	r7, __hyp_stub_vectors
	add r7, r5, r7

/*
	mrc     p15, 0, r0, c0, c0, 5		@ get cpu id http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDGIJFB.html
	ubfx    r0, r0, #0, #2
	lsl		r0, #2
	
	add r5, r5, #0x8100
	str r7, [r5,r0]

*/


	@ Now install the hypervisor stub:
	mcr	p15, 4, r7, c12, c0, 0	@ set hypervisor vector base (HVBAR)

/*	mrc	p15, 4, r7, c12, c0, 0	@ get HVBAR
	add r5, r5, #0x40
	str r7, [r5,r0]
*/
	@ Disable all traps, so we dont get any nasty surprise
	mov	r7, #0

// FIQ/IRQ to hypervisor
//	orr r7, r7, #0xc0

	mcr	p15, 4, r7, c1, c1, 0	@ HCR
	mcr	p15, 4, r7, c1, c1, 2	@ HCPTR
	mcr	p15, 4, r7, c1, c1, 3	@ HSTR

//THUMB(	orr	r7, #(1 << 30)	)	@ HSCTLR.TE
//ARM_BE8(orr	r7, r7, #(1 << 25))     @ HSCTLR.EE
	mcr	p15, 4, r7, c1, c0, 0	@ HSCTLR

	mrc	p15, 4, r7, c1, c1, 1	@ HDCR
	and	r7, #0x1f		@ Preserve HPMN
	mcr	p15, 4, r7, c1, c1, 1	@ HDCR

	@ make CNTP_* and CNTPCT accessible from PL1
	mrc	p15, 0, r7, c0, c1, 1	@ ID_PFR1
	lsr	r7, #16
	and	r7, #0xf
	cmp	r7, #1
	bne	__hyp_stub_install_secondary_finish
	mrc	p15, 4, r7, c14, c1, 0	@ CNTHCTL
	orr	r7, r7, #3		@ PL1PCEN | PL1PCTEN
	mcr	p15, 4, r7, c14, c1, 0	@ CNTHCTL
	mov	r7, #0
	mcrr	p15, 4, r7, r7, c14	@ CNTVOFF

	@ Disable virtual timer in case it was counting
	mrc	p15, 0, r7, c14, c3, 1	@ CNTV_CTL
	bic	r7, #1			@ Clear ENABLE
	mcr	p15, 0, r7, c14, c3, 1	@ CNTV_CTL
__hyp_stub_install_secondary_finish:
	bx	lr			@ The boot CPU mode is left in r4.
// end of__hyp_stub_install_secondary:


//																																				
// NEVER USE the area of 0x100~0x300 !!!!!!!!!!!!!!!
//																																																																																					
//NEVER_USE_100_300:
//.rept 150
//.word 0
//.endr


jmp_loader:
@ Check which proc we are and run proc 0 only

	mrc p15, 0, r0, c1, c0, 0 @ Read System Control Register
	orr r0, r0, #(1<<2)       @ cache enable
	orr r0, r0, #(1<<12)      @ icache enable
	mcr p15, 0, r0, c1, c0, 0 @ Write System Control Register
	

	mrc p15, 0, r0, c1, c0, 1 @ Read Auxiliary Control Register
	orr r0, r0, #(1<<6)       @ SMP
	mcr p15, 0, r0, c1, c0, 1 @ Write Auxiliary Control Register

	mov r0, #1
	mcr p15, 0, r0, c14, c3, 1 @ CNTV_CTL (enable=1, imask=0)

@ set to non-sec
	movw	r1, #0x3fff
	movt	r1, #0x0006
	mcr	p15, 0, r1, c1, c1, 2		@ NSACR = all copros to non-sec
@ timer frequency
//	mov	r1, #19200000 				//0x 124f800
	mov	r1,  #0x1240000
	add r1, r1, #0xf800				//#19200000
	mcr	p15, 0, r1, c14, c0, 0		@ write CNTFRQ

	adrl	r1, _start
	mcr	p15, 0, r1, c12, c0, 1		@ set MVBAR to secure vectors
	mrc	p15, 0, ip, c12, c0, 0		@ save secure copy of VBAR

// test HVBAR for ZZK
/*
	mrc	p15, 4, r7, c12, c0, 0	@ get HVBAR
	ldr r5, =0x3afff020
	str r7, [r5]

	add r5, r5, #0x40
	str r7, [r5]
*/
// test HVBAR for ZZK



// till here we are in secure SVC
	isb
	smc #0				@ call into MONITOR mode
// from this point we are in non-secure HVC
// test HVBAR for ZZK

	mrc	p15, 4, r7, c12, c0, 0	@ get HVBAR
	ldr r5, =0x3afff010
	
	mrc     p15, 0, r8, c0, c0, 5		@ get cpu id http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDGIJFB.html
	ubfx    r8, r8, #0, #2

	lsl r8, r8, #2

	str r7, [r5, r8]

	add r5, r5, #0x40
	str r7, [r5, r8]

// test HVBAR for ZZK
	mcr	p15, 0, ip, c12, c0, 0		@ write non-secure copy of VBAR

// get CPU ID, save in r8
	mrc     p15, 0, r8, c0, c0, 5		@ get cpu id http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDGIJFB.html
	ubfx    r8, r8, #0, #2

// set up stack and save context
	mov sp, #0x3B000000
	sub sp, sp, #0x2000 	// reserve for static variables(0x3b000000-0x2000) and debug (0x3b000000-0x1000)
	mov r11, sp
	movw r10, #0xABCD
	movt r10, #0xEFAB
	str r10, [r11]
 	// for different core use different stack
	mov r0, r8
	mov r0, r0, lsl#0xa            // coreID * 0x400
	sub sp, sp, r0
	
// copy ourself to 0x3AF00000, and set up stage 2 page table
// only do once on core0, all other cores use the same one.
	
	cmp r8, #0
	bne NOT_CORE0
	bl copy_code
	bl stage2_forPL01_init

	mov r0, #0x0
	str r0, [r11]
	
NOT_CORE0:
WaitCore0Finish:
	ldr r0, [r11]	
	cmp r0, r10
	beq WaitCore0Finish

	bl __hyp_stub_install_secondary

	bl hyp_s2_pt_init

/*	
// Keep core 3 in hypervisor mode, prevent kernel from using it.
	mrc     p15, 0, r0, c0, c0, 5
	ubfx    r0, r0, #0, #2
	cmp     r0, #3
	bleq	ISOLATE_CORE3
*/

	// enable IRQ and FIQ
	cpsie if

	bl switch_to_SVC
// from here we enter svc mode, non-secure

	mov	r4, #0x8000
	mrc     p15, 0, r0, c0, c0, 5		@ get cpu id http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDGIJFB.html
	ubfx    r0, r0, #0, #2
	cmp     r0, #0
	beq     9f
	cmp     r0, #0xff
	bge	10f

// for cpus other than core 0

	mov	r3, #0x0		@ magic
1:
	mov	r5, #0x40000000
	add r5, r5, #0xCC		@ mbox
	ldr	r4, [r5, r0, lsl #4]
	cmp	r4, r3
	beq	1b

	mov	r5, #0x40000000
	add r5, r5, #0x8C		@ mbox
	str	r3, [r5, r0, lsl #4]

// for all cores, jump to start address, stored in r4.	
9:
	mov	r0, #0
	mov	r1, #0xc00			//3138		@ BCM2708 machine id
	add r1, r1, #0x42
	mov	r2, #0x100		@ ATAGS
	bx	r4

// core id > 0x100	
10:
	wfi
	b	10b

copy_code:
// copy ourself to 0x3af00000
		mov r5, #0x3a000000
		add r5, r5, #0xf00000

		mov r0, #0
		mov r1, #0x8000
		12:
		ldr r2, [r0]
		str r2, [r5, r0]
		add r0, r0, #4
		cmp r0, r1
		blt 12b

		mov pc, lr
// now we run at address of 0x3af0 0000 ~ 0x3af0 8000 area --- NO!
// end of copy_code

// end jmp_loader


#define R0_POSITION		0x0
#define R1_POSITION		0x4
#define R2_POSITION		0x8
#define R3_POSITION		0xC
#define R4_POSITION		0x10
#define R5_POSITION		0x14
#define R6_POSITION		0x18
#define R7_POSITION		0x1C
#define R8_POSITION		0x20
#define R9_POSITION		0x24
#define R10_POSITION		0x28
#define R11_POSITION		0x2C
#define R12_POSITION		0x30
#define SP_POSITION		0x34
#define LR_POSITION		0x38
#define PC_POSITION		0x3C


__hyp_stub_do_trap:

		// set up stack and save context
	 	// for different core use different stack
	 	mrc p15, 0, sp, c0, c0, 5 		// get current core ID

		and sp, sp, #0x3 
		mov sp, sp, lsl#0xa            // coreID * 0x400

		add sp, sp, #0x3B000000
		sub sp, sp, #0x8000

		// save all registers
		push {r0-r12, lr}
	 	mrc p15, 4, r4, c5, c2, 0        //read hsr to r4

		mov r5, r4
//+++debug		
		mov r11, #0x3b000000
		sub r11, r11, #0x2000
		mov r12, #0

        str r11, [r11, r12]
        add r12, r12, #4

        str r5, [r11, r12]
        add r12, r12, #4
//---debug

        lsr r4, #0x1a
        cmp r4, #0x24                           //hsr[31:25] == 0x24 indicates data abort routed to hyp mode, not allowed access permission on PTE
        bne Non_pfault

// page fault		
		mov r0, #'D'
		bl UART_SEND_CHAR

		mov r0, #'D'
		bl UART_SEND_CHAR

		mrs r0, elr_hyp                                 //must have. change return value to the address of next instruction
		add r0, r0, #4
		msr elr_hyp, r0        

        pop {r0-r12, lr}
        eret

Non_pfault:

/*	 	bl UART_SEND_CHAR_CR_LF
		mov r0, #'H'
		bl UART_SEND_CHAR
		bl UART_SEND_CHAR_CR_LF
*/	 	
	 	mov r10, lr, lsr#0xa
	 	add r10, r10, #0x1

	 	movw r9, 0x8000
	 	movt r9, 0x3af0

	 	ldr r5, [r9]
	 	cmp r5, #0x80000000
	 	movhi r5, #0x0
	 	add r5, r5, #0x1
	 	str r5, [r9]

	 	add r9, r10, lsl#0x9			// 0x200

	 	str sp, [r9, #SP_POSITION]
	 	str r0, [r9, #R0_POSITION]
	 	str r1, [r9, #R1_POSITION]

		cmp     r0, #0x43			  // hap dev, for test.
		cmpeq   r1, #0x43
		cmpeq   r2, #0x43
		cmpeq   r3, #0x43
		beq		HAP_DEV

		pop {r0-r12, lr}
		eret
		b .



HAP_DEV:

		bl UART_SEND_CHAR_CR_LF
		mov r0, #'H'
		bl UART_SEND_CHAR
		bl UART_SEND_CHAR_CR_LF
		
		pop {r0-r12, lr}
		eret

ERET_FROM_HVC:
		pop {r1}
		pop {r1-r12, lr}
		eret


// functions for debug
.global UART_SEND_CHAR_CR_LF
//ENTRY(UART_SEND_CHAR_CR_LF)
UART_SEND_CHAR_CR_LF:
		push {r0, lr}
		mov r0, #0x0d					// '\r'
		bl UART_SEND_CHAR
		mov r0, #0x0a					// '\n'
		bl UART_SEND_CHAR
		pop {r0, pc}
//ENDPROC(UART_SEND_CHAR_CR_LF)

//ENTRY(UART_SEND_CHAR)
.global UART_SEND_CHAR
UART_SEND_CHAR:
		push {r1, r2, r3, lr}
		mov r3, #0
WAIT_FIFO_NOT_FULL:	
//		bl rsa_self_test
		//	ldr r1, =0x3f201018
		movw r1, #0x1018
		movt r1, #0x3f20
		ldr r1, [r1]
		mov r2, #0x20
		and r1, r1, r2
		add r3, r3, #1
		cmp r3, #0x1000
		beq WRITE_UART_FORCE
		cmp r1, #0
		bne WAIT_FIFO_NOT_FULL

WRITE_UART_FORCE:	
		//	ldr r1, =0x3f201000
		movw r1, 0x1000
		movt r1, 0x3f20
		strb r0, [r1] 
		pop {r1, r2, r3, pc}
//ENDPROC(UART_SEND_CHAR)


.align 5
__hyp_stub_vectors:
__hyp_stub_reset:	b __hyp_stub_do_reset
__hyp_stub_und:		b __hyp_stub_do_und
__hyp_stub_svc:		b __hyp_stub_do_svc
__hyp_stub_pabort:	b __hyp_stub_do_pabort
__hyp_stub_dabort:	b __hyp_stub_do_dabort
__hyp_stub_trap:	b __hyp_stub_do_trap
__hyp_stub_irq:		b __hyp_stub_do_irq
__hyp_stub_fiq:		b __hyp_stub_do_fiq



__hyp_stub_do_reset :
	mov r0, #'R'
	b __hyp_stub
__hyp_stub_do_und :
	mov r0, #'U'
	b __hyp_stub
__hyp_stub_do_svc :
	mov r0, #'S'
	b __hyp_stub
__hyp_stub_do_pabort :
	mov r0, #'P'
	b __hyp_stub
__hyp_stub_do_irq :
	mov r0, #'I'
	b __hyp_stub
__hyp_stub_do_fiq :
	mov r0, #'F'
	b __hyp_stub
__hyp_stub_do_dabort:
    mov r0, #'D'
    b __hyp_stub

__hyp_stub:
		bl UART_SEND_CHAR_CR_LF
		bl UART_SEND_CHAR
        bl UART_SEND_CHAR_CR_LF
	    b .

hyp_s2_pt_init:

        mrrc p15, 6, r0, r1, c2     @read VTTBR
        mov r2, #0xffffff00

        and r1, r1, r2 
        mov r2, #0x3a000000
        
        mcrr p15, 6, r2, r1, c2     @Set  VTTBR
        isb

        ldr r1, =0x00003558

        mrc     p15, 4, r0, c2, c1, 2   @read VTCR
        orr r1, r1, r0
        mcr     p15, 4, r1, c2, c1, 2   @Set  VTCR

        mov r0, #0x1
        //ldr r0, =0x11                 @Test HCR.IOM
        mcr p15, 4, r0, c1, c1, 0       @ HCR
        isb
        dsb

        //flush TLB
        mov r0, #0
        //TLBIALLIS (rt ignored)
        mcr p15, 0, r0, c8, c3, 0
//      mcr     p15, 0, r0, c7, c14, 0  //clean and invalidate D cache
        isb
        dsb

	bx lr

.global save_reg
save_reg:
	str r1, [r0]
	bx lr

shutdown:
	push {r0, r1, lr}
	
	mov r0, #'R'
	bl UART_SEND_CHAR
	
	// get current core ID
	mov r1, #'0'
	mrc     p15, 0, r0, c0, c0, 5
	ubfx    r0, r0, #0, #2
	add r0, r0, r1
	
	bl UART_SEND_CHAR


// disable IRQ and FIQ
//	cpsid if

// enable IRQ and FIQ
//	cpsie if

	mov r2, #0x200
DELAY_R2:
	mov r1, #0x10000
DELAY_R1:	
	sub r1, #1
	cmp r1, #0
	bne DELAY_R1
	bl UART_SEND_CHAR_CR_LF
	mov r0, #'O'
	bl UART_SEND_CHAR
	bl UART_SEND_CHAR_CR_LF

	sub r2, #1
	cmp r2, #0
	bne DELAY_R2



	mov r2, #0x10000
shutdown_loop0:
	sub r2, r2, #1
	cmp r2, #0
	bne shutdown_loop0

	//writel(pm_rsts, __io_address(PM_RSTS));
	ldr r0, =0x3f100020
//	ldr r1, =0x5a000555			// for shutdown
	ldr r1, =0x5a000000			// for reboot
	str r1, [r0]

	//writel(pm_wdog, __io_address(PM_WDOG));
	ldr r0, =0x3f100024
	ldr r1, =0x5a00000a
	str r1, [r0]

	//writel(pm_rstc, __io_address(PM_RSTC));
	ldr r0, =0x3f10001c
	ldr r1, =0x5a003222
	str r1, [r0]

	mov r1, #0x10000

shutdown_loop:
	mov r2, #0x10000

	mov r0, #'Q'
	bl UART_SEND_CHAR
	
shutdown_loop1:
	sub r2, r2, #1
	cmp r2, #0
	bne shutdown_loop1
	sub r1, r1, #1
	cmp r1, #0
	bne shutdown_loop

	pop {r0, r1, pc}



/*
arch_counter_get_cntvct:
isb	sy
mrrc	15, 1, r0, r1, cr14
ret

arch_counter_get_cntpct:
isb	sy
mrrc	15, 0, r0, r1, cr14
ret
*/



.GLOBAL ret_idivmod_values ;
.GLOBAL ret_uidivmod_values ;

ret_idivmod_values:
        bx lr

ret_uidivmod_values:
        bx      lr



