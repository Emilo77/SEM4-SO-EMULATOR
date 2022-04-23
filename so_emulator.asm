global so_emul


%ifndef CORES
%define CORES 4
%endif


%define arg1_code r11b
%define arg1 r14b
%define arg2 r15b
%define imm8 r15b

%define A [rel registers]
%define D [rel registers + 1]
%define X [rel registers + 2]
%define Y [rel registers + 3]
%define PC [rel registers + 4]
%define UNUSED [rel registers + 5]
%define C [rel registers + 6]
%define Z [rel registers + 7]


section .rodata

section .bss

registers resb 8

section .text
so_emul:

push rbx
push r12
push r13
push r14
push r15

xor r11, r11 ; zmienna pomocnicza
xor r12, r12
xor r13, r13
xor r14, r14 ; index pierwszego argumentu
xor r15, r15 ; index drugiego argumentu lub imm8

mov r12, rcx ; ilość rdzeni trzymana w r12
mov r13, rdx ; ilość instrukcji trzymana w r13

xor rax, rax ; aktualna instrukcja
xor rbx, rbx
xor rcx, rcx ; counter instrukcji

instruction_loop:
xor arg1, arg1 ; zerowanie argumentów funkcji
xor arg2, arg2 ; zerowanie argumentów funkcji
mov ax, word [rdi + 2 * r13] ; pobieramy instrukcję

cmp ah, 0x40 ; sprawdzenie, czy to instrukcja dwuargumentowa
jl check_two_args_i ; jeśli tak, to sprawdzamy która dokładnie

mov dl, byte ah
mov arg1_code, byte dl
shr dl, 3
shl dl, 3
sub arg1_code, dl
mov arg2, byte al
;todo ustawić dobrze arg1

cmp ah, 0x48 ; sprawdzenie, czy instrukcja to MOVI
jl movi_i
cmp ah, 0x58 ; sprawdzenie, czy instrukcja niepoprawna
jl ignore
cmp ah, 0x60 ; sprawdzenie, czy instruxja to XORI
jl xori_i
cmp ah, 0x68 ; sprawdzenie, czy instrukcja to ADDI
jl addi_i
cmp ah, 0x70 ; sprawdzenie, czy instrukcja to CMPI
jl cmpi_i
cmp ah, 0x78 ; sprawdzenie, czy instrukcją może być RCR
jl check_rcr
cmp ah, 0x80 ; sprawdzenie, czy instrukcją może być CLC
je check_clc
cmp ah, 0x81 ; sprawdzenie, czy instrukcją może być STC
je check_stc
cmp ah, 0xc0 ; sprawdzenie, czy instrukcja to JMP
je jmp_i
cmp ah, 0xc2 ; sprawdzenie, czy instrukcja to JNC
je jnc_i
cmp ah, 0xc3 ; sprawdzenie, czy instrukcja to JC
je jc_i
cmp ah, 0xc4 ; sprawdzenie, czy instrukcja to JNZ
je jnz_i
cmp ah, 0xc5 ; sprawdzenie, czy instrukcja to JZ
je jz_i
cmp ah, 0xff ; sprawdzenie, czy instrukcja to BRK
je check_brk
jmp ignore ; jeśli jest niepoprawna, ignorujemy

check_two_args_i:
;mov dl, byte ah
;mov r11b, byte dl
;shr dl, 3
;shl dl, 3
;sub r11b, dl ; r11b to kod arg1
;
;mov arg2, byte al
;todo ustawić dobrze arg1 i arg2


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
;todo zapisać arg1 do rejestru
inc byte PC
instruction_done_after_jump:
inc rcx
cmp rcx, r13 ;sprawdzamy, czy wykonaliśmy już steps instrukcji
jne instruction_loop ; jeśli nie, to parsujemy i wykonujemy kolejną
jmp end ; jeśli wszystkie, kończymy program


mov_i:
mov arg1, arg2 ; przypisujemy do arg1 wartość arg2
jmp instruction_done ; zakończenie instrukcji

or_i:
mov Z, byte 0 ; zerujemy Z
or arg1, arg2
jnz instruction_done ; jeśli flaga Z nieustawiona, kończymy instrukcję
mov Z, byte 1 ; ustawiamy flagę Z
jmp instruction_done ; zakończenie instrukcji


add_i:
mov Z, byte 0 ; zerujemy Z
add arg1, arg2
jnz instruction_done ; jeśli flaga Z nieustawiona, kończymy instrukcję
mov Z, byte 1 ; ustawiamy flagę Z
jmp instruction_done ; zakończenie instrukcji

sub_i:
mov Z, byte 0 ; zerujemy Z
sub arg1, arg2
jnz instruction_done ; jeśli flaga Z nieustawiona, kończymy instrukcję
mov Z, byte 1 ; ustawiamy flagę Z
jmp instruction_done ; zakończenie instrukcji

adc_i:
mov Z, byte 0
mov C, byte 0
adc arg1, arg2
jnz adc_check_C_flag ; todo sprawdzić, czy jnz zeruje carry flag
mov Z, byte 1
adc_check_C_flag:
jnc instruction_done
mov C, byte 1
jmp instruction_done

sbb_i:
mov Z, byte 0
mov C, byte 0
sbb arg1, arg2
jnz sbb_check_C_flag ; todo sprawdzić, czy jnz zeruje carry flag
mov Z, byte 1
sbb_check_C_flag:
jnc instruction_done
mov C, byte 1
jmp instruction_done

movi_i:
mov arg1, imm8
jmp instruction_done

xori_i:
mov Z, byte 0 ; zerujemy Z
xor arg1, imm8
jnz instruction_done ; jeśli flaga Z nieustawiona, kończymy instrukcję
mov Z, byte 1 ; ustawiamy flagę Z
jmp instruction_done ; zakończenie instrukcji


addi_i:
mov Z, byte 0 ; zerujemy Z
add arg1, imm8
jnz instruction_done ; jeśli flaga Z nieustawiona, kończymy instrukcję
mov Z, byte 1 ; ustawiamy flagę Z
jmp instruction_done ; zakończenie instrukcji

cmpi_i:
mov Z, byte 0
mov C, byte 0
cmp arg1, imm8
jnz cmpi_check_C_flag ; todo sprawdzić, czy jnz zeruje carry flag
mov Z, byte 1
cmpi_check_C_flag:
jnc instruction_done
mov C, byte 1
jmp instruction_done

rcr_i:
cmp C, byte 0
jz instruction_done
shr arg1, 1 ; może shl?
mov C, byte 0
jmp instruction_done

clc_i:
mov C, byte 0
jmp instruction_done

stc_i:
mov C, byte 1
jmp instruction_done

jmp_i:
add PC, imm8
jmp instruction_done

jnc_i:
cmp C, byte 0
jnz instruction_done
add PC, imm8
jmp instruction_done

jc_i:
cmp C, byte 0
jz instruction_done
add PC, imm8
jmp instruction_done

jnz_i:
cmp Z, byte 0
jnz instruction_done
add PC, imm8
jmp instruction_done

jz_i:
cmp Z, byte 0
jz instruction_done
add PC, imm8
jmp instruction_done

brk_i:
jmp end

xchg_i:

end:




mov rax, [rel registers] ;wypełnienie rax wszystkimi elementami struktury
;todo może trzeba przesunąć wskaźnik na code

pop r15
pop r14
pop r13
pop r12
pop rbx

ret