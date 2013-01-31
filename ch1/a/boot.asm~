	org	07c00h			;告诉编译器，程序加载到7c00处
	mov	ax, cs			;使cs的内容 copy 到 ax 寄存器
	mov	ds, ax
	mov	es, ax			;至此，ds跟es 指向 与cs相同的段
	call	DispStr			;调用显示字符串的 子程序
	jmp	$			;无限循环
DispStr:mov	ax, BootMessage		;设置中断服务所需的各种参数
	mov	bp, ax			;ES:BP 为规定的串地址
	mov	cx, 16
	mov	ax, 01301h
	mov	bx, 000ch		;页号,BH=0. 属性,BL=0ch,黑底红字
	mov	dl, 0
	int	10h
	ret
BootMessage:		db	"Hello, OS world!"
times	510-($-$$)	db	0	;填充剩下的空间
dw	0xaa55				;结束标志，2字节（生成的二进制代码正好512字节）
