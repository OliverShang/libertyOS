;===================================================
;　kernel.asm
;===================================================

GDT_SIZE		equ	256 * 8		; 256 个描述符, 每个 8 字节
IDT_SIZE		equ	256 * 8		; 256 个描述符, 每个 8 字节
SELECTOR_VIDEO		equ	8
SELECTOR_FLATC		equ	32
SELECTOR_FLATRW		equ	40
SELECTOR_TSS		equ	48

extern	memcpy			; lib/klib.asm
extern	print			; lib/klib.asm
extern	cstart			; kernel/start.c
extern	excep_handler		; kernel/start.c
extern	irq_handler		; kernel/start.c
extern	p_current_proc		; kernel/main.c
extern	kernel_main		; kernel/main.c
extern	f_reenter		; kernel/main.c
extern	clock_handler		; kernel/clock.c
extern	syscall_table		; kernel/main.c
extern	keyboard_handler	; kernel/keyboard.c
extern	hd_handler		; kernel/hd.c

global	_start
global	GDT
global	IDT
global	TSS

global	divide_error
global	reserved
global	nmi
global	breakpoint
global	overflow
global	out_of_bound
global	invalid_opcode
global	no_math_coprocessor
global	double_fault
global	coprocessor_error
global	invalid_tss
global	not_present
global	stack_error
global	general_protect
global	page_fault
global	intel_reserved
global	mcu_fault
global	align_check
global	mechine
global	simd_error

global	irq00_handler
global	irq01_handler
global	irq02_handler
global	irq03_handler
global	irq04_handler
global	irq05_handler
global	irq05_handler
global	irq06_handler
global	irq07_handler
global	irq08_handler
global	irq09_handler
global	irq10_handler
global	irq11_handler
global	irq12_handler
global	irq13_handler
global	irq14_handler

global	proc_begin

global	sys_call

[SECTION .data]
;-------------------------------------------------------------------------------------
GDT:	times	GDT_SIZE db 0

GdtPtr:	dw	0		; GDT 界限
	dd	0		; GDT 线性基地址
;-------------------------------------------------------------------------------------

IDT:	times	IDT_SIZE db 0

IdtPtr:	dw	IDT_SIZE - 1	; IDT 界限
	dd	IDT		; IDT 线性基地址

;-------------------------------------------------------------------------------------

TSS:
		dd	0			; PREV_TSS
TSS_ESP0	dd	0			; ESP0
		dd	SELECTOR_FLATRW		; SS0
		dd	0			; ESP1
		dd	0			; SS1
		dd	0			; ESP2
		dd	0			; SS2
		dd	0			; CR3
		dd	0			; EIP
		dd	0			; EFLAGS
		dd	0			; EAX
		dd	0			; ECX
		dd	0			; EDX
		dd	0			; EBX
		dd	0			; ESP
		dd	0			; EBP
		dd	0			; ESI
		dd	0			; EDI
		dd	0			; ES
		dd	0			; CS
		dd	0			; SS
		dd	0			; DS
		dd	0			; FS
		dd	0			; GS
		dd	0			; LDT 选择子
		dw	0			; 保留
		dw	TSSLen			; I/O　许可位图基地址大于或等于 TSS 界限, 则表示没有 I/O 许可位图

TSSLen	equ	$ - TSS

;-------------------------------------------------------------------------------------

[SECTION .bss]
StackSpace	resb	2 * 1024	; 2K
BottomOfStack:	; 栈底


[SECTION .text]
_start:
	; 切换 GDT
	sgdt	[GdtPtr]

	mov	ax, word [GdtPtr]	; ax <- gdt_limit
	inc	ax			; gdt_size
	movzx	eax, ax
	push	eax			; len
	push	dword [GdtPtr + 2]	; pSrc (gdt_base)
	push	dword GDT		; pDst
	call	memcpy
	add	esp, 12

	mov	word [GdtPtr], GDT_SIZE - 1
	mov	dword [GdtPtr + 2], GDT
	lgdt	[GdtPtr]

	; 刷新段选择器的描述符高速缓存器
	mov	ax, SELECTOR_FLATRW
	mov	ds, ax
	mov	es, ax

	; 切换栈
	mov	ss, ax
	mov	esp, BottomOfStack
	
	mov	ax, SELECTOR_VIDEO
	mov	gs, ax

	; 刷新 CS 描述符高速缓存器
	jmp	SELECTOR_FLATC:LABEL
LABEL:
	call	cstart
	lidt	[IdtPtr]
	
	mov	ax, SELECTOR_TSS
	ltr	ax
	
	jmp	kernel_main

	hlt

; 0 ~ 19 中断异常处理例程 -------------------------------------------------------------------
; `push`　对应的 esp 指向进程表, 但无需将其改为内核栈栈底`BottomOfStack`, 因为
; 异常发生后将使用 hlt 停机, 即使破坏进程表也无所谓.
; ------------------------------------------------------------------------------------------
divide_error:
	push	0			; "err_code = 0" means that no error code actually.
	push	0			; vecno = 0
	jmp	Call_excep_handler

reserved:
	push	0			; no error code
	push	1			; vecno = 1
	jmp	Call_excep_handler

nmi:
	push	0			; no error code
	push	2			; vecno = 2
	jmp	Call_excep_handler

breakpoint:
	push	0			; no error code
	push	3			; vecno = 3
	jmp	Call_excep_handler

overflow:
	push	0			; no error code
	push	4			; vecno = 4
	jmp	Call_excep_handler

out_of_bound:
	push	0			; no error code
	push	5			; vecno = 5
	jmp	Call_excep_handler

invalid_opcode:
	push	0			; no error code
	push	6			; vecno = 6
	jmp	Call_excep_handler

no_math_coprocessor:
	push	0			; no error code
	push	7			; vecno = 7
	jmp	Call_excep_handler

double_fault:
	push	0			; no error code
	push	8			; vecno = 8
	jmp	Call_excep_handler


coprocessor_error:
	push	0			; no error code
	push	9			; vecno = 9
	jmp	Call_excep_handler

invalid_tss:
	push	0			; no error code
	push	10			; vecno = 10
	jmp	Call_excep_handler

not_present:
	push	0			; no error code
	push	11			; vecno = 11
	jmp	Call_excep_handler


stack_error:
	push	0			; no error code
	push	12			; vecno = 12
	jmp	Call_excep_handler

general_protect:
	push	13			; vecno = 13
	jmp	Call_excep_handler

page_fault:
	push	0			; no error code
	push	14			; vecno = 14
	jmp	Call_excep_handler

intel_reserved:
	push	0			; no error code
	push	15			; vecno = 15
	jmp	Call_excep_handler

mcu_fault:
	push	0			; no error code
	push	16			; vecno = 16
	jmp	Call_excep_handler

align_check:
	push	0			; no error code
	push	17			; vecno = 17
	jmp	Call_excep_handler

mechine:
	push	0			; no error code
	push	18			; vecno = 18
	jmp	Call_excep_handler

simd_error:
	push	0			; no error code
	push	19			; vecno = 19
	jmp	Call_excep_handler

Call_excep_handler:
	; 此时的栈:
;	|  vecno   |	
;	| err_code |
;	|   eip    |
;	|   cs     |
;	|  eflags  |
;
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	
	call	excep_handler
	add	esp, 8
	hlt


; 8259A 中断异常处理例程 ----------------------------------------------------

irq00_handler:				; 时钟
	pushad
	push	ds
	push	es
	push	fs
	push	gs
	
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	
	mov	al, 20h ; `.
	out	20h, al	; / 向主8259A发送 EOI
	
	sti
	inc	dword [f_reenter]
	cmp	dword [f_reenter], 0	; f_reenter = 0 则没有发生中断重入
	je	.no_reenter
	jmp	.reenter	
.no_reenter:
	cli
	mov	esp, BottomOfStack	; 内核栈
	call	clock_handler
	
	jmp	proc_begin
.reenter:
	jmp	proc_begin_reenter
	
;--------------------------------------------------------------------------

irq01_handler:				; 键盘
	pushad
	push	ds
	push	es
	push	fs
	push	gs
	
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	
	mov	al, 20h ; `.
	out	20h, al	; / 向主8259A发送 EOI
	
	sti
	inc	dword [f_reenter]
	cmp	dword [f_reenter], 0	; f_reenter = 0 则没有发生中断重入
	je	.no_reenter
	jmp	.reenter	
.no_reenter:
	cli
	mov	esp, BottomOfStack	; 内核栈
	call	keyboard_handler
	
	jmp	proc_begin
.reenter:
	jmp	proc_begin_reenter
	
;--------------------------------------------------------------------------

irq02_handler:
	push	2			; irqno = 2
	jmp	Call_irq_handler

irq03_handler:
	push	3			; irqno = 3
	jmp	Call_irq_handler

irq04_handler:
	push	4			; irqno = 4
	jmp	Call_irq_handler

irq05_handler:
	push	5			; irqno = 5
	jmp	Call_irq_handler

irq06_handler:
	push	6			; irqno = 6
	jmp	Call_irq_handler

irq07_handler:
	push	7			; irqno = 7
	jmp	Call_irq_handler

irq08_handler:
	push	8			; irqno = 8
	jmp	Call_irq_handler

irq09_handler:
	push	9			; irqno = 9
	jmp	Call_irq_handler

irq10_handler:
	push	10			; irqno = 10
	jmp	Call_irq_handler

irq11_handler:
	push	11			; irqno = 11
	jmp	Call_irq_handler

irq12_handler:
	push	12			; irqno = 12
	jmp	Call_irq_handler

irq13_handler:
	push	13			; irqno = 13
	jmp	Call_irq_handler

;---------------------------------------------------------------------------

irq14_handler:				; AT 温盘
	pushad
	push	ds
	push	es
	push	fs
	push	gs
	
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	
	mov	al, 20h ; `.
	out	20h, al	; / 向主8259A发送 EOI
	
	mov	al, 20h ; `.
	out	0A0h, al; / 向从8259A发送 EOI
	
	sti
	inc	dword [f_reenter]
	cmp	dword [f_reenter], 0	; f_reenter = 0 则没有发生中断重入
	je	.no_reenter
	jmp	.reenter	
.no_reenter:
	cli
	mov	esp, BottomOfStack	; 内核栈
	call	hd_handler
	
	jmp	proc_begin
.reenter:
	jmp	proc_begin_reenter

;---------------------------------------------------------------------------
	
Call_irq_handler:
	call	irq_handler
	add	esp, 4
	iretd
;---------------------------------------------------------------------------

sys_call:
	pushad
	push	ds
	push	es
	push	fs
	push	gs
	
	mov	esi, eax	; save eax
	
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	
	mov	eax, esi	; resume eax
	
	sti
	
	inc	dword [f_reenter]
	cmp	dword [f_reenter], 0	; f_reenter = 0 则没有发生中断重入
	je	.no_reenter
	jmp	.reenter	
.no_reenter:
	cli
	mov	esp, BottomOfStack	; 内核栈
	
	push	dword [p_current_proc]
	push	edx
	push	ecx
	push	ebx
	call	[syscall_table + eax * 4]
	add	esp, 12
	
	pop	esi			; esi <- [p_current_proc]
	mov	[esi + EAX_OFFSET], eax	; return value
	
	jmp	proc_begin
.reenter:
	jmp	proc_begin_reenter
	
;---------------------------------------------------------------------------

proc_begin:
	mov	esp, [p_current_proc]
	lldt	[esp + LDT_SEL_OFFSET]
	lea	eax, [esp + STACK_BUTTOM_OFFSET]
	mov	dword [TSS_ESP0], eax
proc_begin_reenter:
	dec	dword [f_reenter]
	pop	gs
	pop	fs
	pop	es
	pop	ds
	popad

	iretd

; STACK_FRAME 结构体内各个字段相对结构体首部的偏移
EAX_OFFSET		equ	44
K_ESP_OFFSET		equ	28
SS_OFFSET		equ	64
STACK_BUTTOM_OFFSET	equ	68
LDT_SEL_OFFSET		equ	68
