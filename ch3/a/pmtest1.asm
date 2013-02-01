%include	"pm.inc.asm"	; consts, macro, and some notes.

org	0100h	; dos/com.
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;
LABEL_GDT         : Descriptor 0       , 0                , 0            ; empty descriptor
LABEL_DESC_CODE32 : Descriptor 0       , SegCode32Len - 1 , DA_C + DA_32 ; unconfirming code segment
LABEL_DESC_VIDEO  : Descriptor 0B8000h , 0ffffh           , DA_DRW       ; video memory first address
; end of GDT.

GdtLen		equ	$ - LABEL_GDT	; GDT length
GdtPtr		dw	GdtLen - 1	; GDT limit
		dd	0		; GDT base address
; GDT selector	(is descriptor's offset to GDT there)
SelectorCode32	equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorVideo	equ	LABEL_DESC_VIDEO	- LABEL_GDT
;end of [SECTION .gdt]

; a 16 bit section( code segment ? ).
[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; init 32 bit code segment descriptor - LABLE_DESC_CODE32 ( LABEL_SEG_CODE32 is 32 bit base address ).
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah
	
	; prepare to load GdtPtr to GDTR(gdt register)
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt base address
	mov	dword [GdtPtr + 2], eax ; [GdtPtr +2] <- gdt base addr.

	; load GDTR
	lgdt	[GdtPtr]

	; close interrupt
	cli

	; enable A20 gate (fast)
	in	al, 92h
	or	al, 02h
	out	92h, al

	; prepare to switch to protected mode( cr0's lowest bit - PE bit)
	mov	eax, cr0
	or	eax, 1	; PE bit <- 1
	mov	cr0, eax
	
	; jump to protected mode
	jmp	dword SelectorCode32:0	; load SelectorCode32 to cs & jump to SelectorCode32:0.
	
; end of [SECTION .s16]

; 32 bit code segment. jump from real mode.
[SECTION .s32]
[BITS 32]

LABEL_SEG_CODE32:
	mov	ax, SelectorVideo
	mov	gs, ax		; video segment selector

	mov	edi, (80 * 11 + 79) * 2 ; row 11, 79 col
	mov	ah, 0Ch		; 0000: black background	1100: red foreground.
	mov	al, 'P'
	mov	[gs:edi], ax

	; END
	jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32	; length of the 32 bit code segment
; END of [SECTION .s32]

