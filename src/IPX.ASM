IPXSPX_REGS struc
  rax dw ?
  rbx dw ?
  rcx dw ?
  rdx dw ?
  rsi dw ?
  rdi dw ?
  res dw ?
IPXSPX_REGS ends

EXTRN ipxspx_drv_entry

CODE SEGMENT BYTE PUBLIC
PUBLIC IPXENTR
PUBLIC IPXINIT

IPXENTR:
push bp
mov bp,sp
push es
push di
push si
push dx
push cx
push bx
push ax
push ds
mov bx,[bp+4]
mov ds,[bp+6]
mov es,ds:[bx].res
mov di,ds:[bx].rdi
mov si,ds:[bx].rsi
mov dx,ds:[bx].rdx
mov cx,ds:[bx].rcx
mov ax,ds:[bx].rax
mov bx,ds:[bx].rbx
pop ds
call [dword ptr ipxspx_drv_entry]
push ds
push dx
mov dx,bx
mov bx,[bp+4]
mov ds,[bp+6]
mov ds:[bx].rax,ax
mov ds:[bx].rcx,cx
mov ds:[bx].rbx,bx
pop dx
mov ds:[bx].rdx,dx
mov ds:[bx].rsi,si
mov ds:[bx].rdi,di
pop ds
pop ax
pop bx
pop cx
pop dx
pop si
pop di
pop es
pop bp
ret 2

IPXINIT:
push bp
mov bp,sp
mov ax,7A00H
int 2FH
mov word ptr ipxspx_drv_entry+2,es
mov word ptr ipxspx_drv_entry,di
mov ah,0
pop bp
ret 0

CODE ENDS
end
