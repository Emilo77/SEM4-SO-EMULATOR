global so_emul


%ifndef CORES
%define CORES 4
%endif

%define carry_flag r12b
%define zero_flag r13b
%define arg1 r14b
%define arg2 r15b
%define imm8 r15b

%define A [rel registers]
%define D [rel registers + 1]
%define X [rel registers + 2]
%define Y [rel registers + 3]
%define PC [rel registers + 4]
%define C [rel registers + 5]
%define Z [rel registers + 6]


section .rodata

section .bss

registers resb 7

section .text
so_emul:

push r12
push r13
push r14
push r15
push rbp
push rbx

xor r12, r12
xor r13, r13
xor r14, r14 ; index pierwszego argumentu
xor r15, r15 ; zmienna pomocnicza

mov r12, rcx ; ilość rdzeni trzymana w r12
mov r13, rdx ; ilość instrukcji trzymana w r13

xor rcx, rcx ; counter instrukcji
xor rbx, rbx ; aktualna instrukcja
xor rax, rax
parse_instruction_loop:
mov ax, word [rdi + 2 * rcx]

cmp ah, 0x40
jl check_two_args_i

mov dl, byte ah
mov r15b, byte dl
shr dl, 3
shl dl, 3
sub r15b, dl
mov rbx, registers
add bl, r15b
mov arg1, byte [rbx] ; todo check


cmp ah, 0x48
jl movi_i
cmp ah, 0x58
jl ignore
cmp ah, 0x60
jl xori_i
cmp ah, 0x68
jl addi_i
cmp ah, 0x70
jl cmpi_i
cmp ah, 0x78
jl check_rcr
cmp ah, 0x80
je check_clc
cmp ah, 0x81
je check_stc
cmp ah, 0xc0
je jmp_i
cmp ah, 0xc2
je jnc_i
cmp ah, 0xc3
je jc_i
cmp ah, 0xc4
je jnz_i
cmp ah, 0xc5
je jz_i
cmp ah, 0xff
je check_brk
jmp ignore

check_two_args_i:
mov dl, byte ah
mov r15b, dl
shr dl, 3
mov rbx, registers
add bl, byte dl
mov arg2, [rbx]
shl dl, 3
sub r15b, dl
mov rbx, registers
add bl, byte r15b
mov arg1, [rbx] ;todo sprawdzić


cmp al, 0x0
je mov_i
cmp al, 0x2
je or_i
cmp al, 0x4
je add_i
cmp al, 0x5
je sub_i
cmp al, 0x6
je adc_i
cmp al, 0x7
je sbb_i
cmp al, 0x8
je xchg_i
jmp ignore

check_rcr:
cmp al, 0x1
je rcr_i
jmp ignore

check_clc:
cmp al, 0x0
je clc_i
jmp ignore

check_stc:
cmp al, 0x0
je stc_i
jmp ignore

check_brk:
cmp al, 0xff
je brk_i
jmp ignore


ignore:
instruction_done:
inc byte PC
inc rcx




mov_i:
mov arg1, arg2
jmp instruction_done

or_i:
xor zero_flag, zero_flag
or arg1, arg2
jnz instruction_done
mov zero_flag, 1
jmp instruction_done

add_i:
xor zero_flag, zero_flag
add arg1, arg2
jnz instruction_done
mov zero_flag, 1
jmp instruction_done

sub_i:
xor zero_flag, zero_flag
sub arg1, arg2
jnz instruction_done
mov zero_flag, 1
jmp instruction_done

adc_i:
xor zero_flag, zero_flag
add arg1, arg2
add arg1, carry_flag
;todo ustawić flagi

sbb_i:
xor zero_flag, zero_flag
sub arg1, arg2
sub arg1, carry_flag
;todo ustawić flagi

movi_i:
mov arg1, imm8

xori_i:
xor zero_flag, zero_flag
xor arg1, imm8
jnz instruction_done
mov zero_flag, 1
jmp instruction_done

addi_i:
xor zero_flag, zero_flag
add arg1, imm8
jnz instruction_done
mov zero_flag, 1
jmp instruction_done

cmpi_i:
xor carry_flag, carry_flag
xor zero_flag, zero_flag
cmp arg1, imm8
;todo ustawić flagi


rcr_i:
cmp carry_flag, 0
je instruction_done
shr arg1, 1
xor carry_flag, carry_flag
jmp instruction_done

clc_i:
xor carry_flag, carry_flag
jmp instruction_done

stc_i:
mov carry_flag, 1
jmp instruction_done

jmp_i:
jnc_i:
jc_i:
jnz_i:
jz_i:


brk_i:
jmp end

xchg_i:

end:

;wypełnienie rax wszystkimi elementami struktury

pop rbx
pop rbp
pop r15
pop r14
pop r13
pop r12

ret