%include	"pm.inc.asm"	;consts, macros, and some notes.

org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
;GDT
;
LABEL_GDT         : Descriptor	0        , 0              , 0             ; empty descr.
LABEL_DESC_NORMAL : Descriptor	0        , 0ffffh         , DA_DRW        ; Normal descr.
LABEL_DESC_CODE32 : Descriptor	0        , SegCode32Len-1 , DA_C+DA_32    ; nonconfirm code seg. 32bits
LABEL_DESC_CODE16 : Descriptor	0        , 0ffffh         , DA_C          ; nonconfirm code seg. 16bits
LABEL_DESC_DATA   : Descriptor	0        , DataLen-1      , DA_DRW        ; Data
LABEL_DESC_STACK  : Descriptor	0        , TopOfStack     , DA_DRWA+DA_32 ; Stack                       , 32bits
LABEL_DESC_TEST   : Descriptor	0500000h , 0ffffh         , DA_DRW
LABEL_DESC_VIDEO  : Descriptor	0B8000h  , 0ffffh         , DA_DRW        ; video memory base address
; end of GDT

GdtLen		equ	$ - LABEL_GDT	; GDT length
GdtPtr		dw	GdtLen - 1	; GDT limit
		dd	0		; GDT base address

; GDT Selector
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorTest		equ	LABEL_DESC_TEST		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; end of [SECTION .gdt]

[SECTION .data1]	; data segment
ALIGN	32	;???
[BITS	32]
LABEL_DATA:
SPValueInRealMode	dw	0
; Strings
PMMessage:	db	"In Protect Mode now. ^_^", 0	; display in protect mode
OffsetPMMessage	equ	PMMessage - $$			; use in protect mode, can't use real mode address in protect mode
StrTest:	db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest	equ	StrTest - $$
DataLen		equ	$ - LABEL_DATA
; end of [SECTION . data1]

; global stack segment 
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times	512	db	0	; 512 bits stack

TopOfStack	equ	$ - LABEL_STACK - 1
; end of [SECTION .gs]

[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h	; for dos / com.

	mov	[LABEL_GO_BACK_TO_REAL+3], ax	; change machine code of "LABEL_GO_BACK_TO_REAL: jmp ...."
	mov	[SPValueInRealMode], sp

	; init 16bits code segment descriptor
	mov	ax, cs
	movzx	eax, ax	; movzx: 0000000000000000ax
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:	; jump back to real mode from protect mode
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax

	mov	sp, [SPValueInRealMode]

	in	al, 92h
	and	al, 11111101b
	out	92h, al

	sti	; open interrupt

	; back to DOS
	mov	ax, 4c00h
	int	21h
; end of [SECTION .s16]

[SECTION .s32]	; 32 bits code segment. jump from real mode
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax
	mov	ax, SelectorTest
	mov	es, ax
	mov	ax, SelectorVideo
	mov	gs, ax

	mov	ax, SelectorStack
	mov	ss, ax

	mov	esp, TopOfStack

	; display a string.
	mov	ah, 0Ch		; 0000: black back, 1100: red fore.
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetPMMessage	; source
	mov	edi, (80 * 10 + 0) * 2	; destination
	cld				; clear direction, so that esi, dsi can go ahead.
.1:
	lodsb	; load from string byte: al <- ds:esi 
	test	al, al
	jz	.2	; end if al = 0
	mov	[gs:edi], ax
	add	edi, 2		; why not 1?
	jmp	.1	; loop
.2:	; display complete.
	
	call	DispReturn

	call	TestRead
	call	TestWrite
	call	TestRead

	; END
	jmp	SelectorCode16:0	; back to .s16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TestRead:
	xor	esi, esi
	mov	ecx, 8
.loop:
	mov	al, [es:esi]
	call	DispAL
	inc	esi
	loop	.loop

	call	DispReturn

	ret

TestWrite:
	push	esi
	push	edi
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetStrTest
	cld
.1:
	lodsb
	test	al, al
	jz	.2
	mov	[es:edi], al
	inc	edi
	jmp	.1
.2:
	pop	edi
	pop	esi

	ret

; ------------------------------------------------------------------------
; 显示 AL 中的数字
; 默认地:
;	数字已经存在 AL 中
;	edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;	ax, edi
; ------------------------------------------------------------------------
DispAL:
	push	ecx
	push	edx

	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	dl, al
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al, 01111b
	cmp	al, 9
	ja	.1
	add	al, '0'
	jmp	.2
.1:
	sub	al, 0Ah
	add	al, 'A'
.2:
	mov	[gs:edi], ax
	add	edi, 2

	mov	al, dl
	loop	.begin
	add	edi, 2

	pop	edx
	pop	ecx

	ret
; DispAL 结束-------------------------------------------------------------

DispReturn:
	push	eax
	push	ebx
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	ebx
	pop	eax

	ret

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; end of [SECTION .s32]

;16 bits code segment ( 32bits code seg. jump to 16bits, then jump to real mode)
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; jump to real mode:
	mov	ax, SelectorNormal
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and	al, 11111110b
	mov	cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; segment addr. will be changed at program beginning.

Code16Len	equ	$ - LABEL_SEG_CODE16

; end of [SECTION .s16code]


