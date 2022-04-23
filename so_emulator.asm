global so_emul


%ifndef CORES
%define CORES 4
%endif


%define arg1_code r11b
%define arg2_code r10b
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

cmp r13, 0 ; sprawdzenie, czy liczba instrukcji jest równa 0
jne instruction_loop ; jeśli nie, orzechodzimy do pętli
jmp end ; jeśli tak, wychodzimy z programu

instruction_loop:
xor arg1, arg1 ; zerowanie argumentów funkcji
xor arg2, arg2 ; zerowanie argumentów funkcji
;xor rbx, rbx
xor r9, r9
mov r9b, PC
mov ax, word [rdi + 2 * r9] ; pobieramy instrukcję

cmp ah, 0x40 ; sprawdzenie, czy to instrukcja dwuargumentowa
jb check_two_args_i ; jeśli tak, to sprawdzamy która dokładnie

mov arg2, byte al ; pobieramy drugi argument
mov dl, byte ah
mov arg1_code, byte dl
shr dl, 3
shl dl, 3
sub arg1_code, dl ; arg1_code = {0, 1, 2, 3, 4, 5, 6, 7}
mov rbx, registers

cmp arg1_code, 3
ja arg1_code_4

add bl, byte arg1_code ; rbx = registers + arg1_code
mov arg1, byte [rbx] ; arg1 = [registers + 0] lub [registers + 1] lub [registers + 2] lub [registers + 3]
jmp pick_instruction

arg1_code_4:
cmp arg1_code, 4
jne arg1_code_5
add bl, 2
mov r10b, byte [rbx] ; r10b = X
mov rbx, rsi
add bl, r10b
mov arg1, byte [rbx] ; arg1 = [X]
jmp pick_instruction

arg1_code_5:
cmp arg1_code, 5
jne arg1_code_6
add bl, 3
mov r10b, byte [rbx] ; r10b = Y
mov rbx, rsi
add bl, r10b
mov arg1, byte [rbx] ; arg1 = [Y]
jmp pick_instruction

arg1_code_6:
cmp arg1_code, 6
jne arg1_code_7
inc bl
mov r10b, byte [rbx] ; r10b = D
inc bl
mov r9b, byte [rbx] ; r9b = X
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + X]
mov arg1, byte [rbx] ; arg1 = [data[D + X]]
jmp pick_instruction

arg1_code_7:
inc bl
mov r10b, byte [rbx] ; r10b = D
add bl, byte 2
mov r9b, byte [rbx] ; r9b = Y
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + Y]
mov arg1, byte [rbx] ; arg1 = [data[D + Y]]

pick_instruction:

cmp ah, 0x48 ; sprawdzenie, czy instrukcja to MOVI
jb movi_i
cmp ah, 0x58 ; sprawdzenie, czy instrukcja niepoprawna
jb ignore
cmp ah, 0x60 ; sprawdzenie, czy instruxja to XORI
jb xori_i
cmp ah, 0x68 ; sprawdzenie, czy instrukcja to ADDI
jb addi_i
cmp ah, 0x70 ; sprawdzenie, czy instrukcja to CMPI
jb cmpi_i
cmp ah, 0x78 ; sprawdzenie, czy instrukcją może być RCR
jb check_rcr
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
mov dl, byte ah
mov arg1_code, byte dl
shr dl, 3
mov arg2_code, dl ; arg2_code = {0, 1, 2, 3, 4, 5, 6, 7}
shl dl, 3
sub arg1_code, dl ; arg1_code = {0, 1, 2, 3, 4, 5, 6, 7}
mov rbx, registers

cmp arg2_code, 3
ja two_arg2_code_4

add bl, arg2_code
mov arg2, byte [rbx]
jmp two_set_arg1

two_arg2_code_4:
cmp arg2_code, 4
jne two_arg2_code_5
add bl, 2
mov r10b, byte [rbx] ; r10b = X
mov rbx, rsi
add bl, r10b
mov arg2, byte [rbx] ; arg2 = [X]
jmp two_set_arg1

two_arg2_code_5:
cmp arg2_code, 5
jne two_arg2_code_6
add bl, 3
mov r10b, byte [rbx] ; r10b = Y
mov rbx, rsi
add bl, r10b
mov arg2, byte [rbx] ; arg2 = [Y]
jmp two_set_arg1

two_arg2_code_6:
cmp arg2_code, 6
jne two_arg2_code_7
inc bl
mov r10b, byte [rbx] ; r10b = D
inc bl
mov r9b, byte [rbx] ; r9b = X
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + X]
mov arg2, byte [rbx] ; arg2 = [data[D + X]]
jmp two_set_arg1

two_arg2_code_7:
inc bl
mov r10b, byte [rbx] ; r10b = D
add bl, byte 2
mov r9b, byte [rbx] ; r9b = Y
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + Y]
mov arg2, byte [rbx] ; arg2 = [data[D + Y]]

two_set_arg1:
xor rbx, rbx
mov rbx, registers

cmp arg1_code, 3
ja two_arg1_code_4

add bl, byte arg1_code ; rbx = registers + arg1_code
mov arg1, byte [rbx] ; arg1 = [registers + 0] lub [registers + 1] lub [registers + 2] lub [registers + 3]
jmp two_pick_instruction

two_arg1_code_4:
cmp arg1_code, 4
jne two_arg1_code_5
add bl, 2
mov r10b, byte [rbx] ; r10b = X
mov rbx, rsi
add bl, r10b
mov arg1, byte [rbx] ; arg1 = [X]
jmp two_pick_instruction

two_arg1_code_5:
cmp arg1_code, 5
jne two_arg1_code_6
add bl, 3
mov r10b, byte [rbx] ; r10b = Y
mov rbx, rsi
add bl, r10b
mov arg1, byte [rbx] ; arg1 = [Y]
jmp two_pick_instruction

two_arg1_code_6:
cmp arg1_code, 6
jne two_arg1_code_7
inc bl
mov r10b, byte [rbx] ; r10b = D
inc bl
mov r9b, byte [rbx] ; r9b = X
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + X]
mov arg1, byte [rbx] ; arg1 = [data[D + X]]
jmp two_pick_instruction

two_arg1_code_7:
inc bl
mov r10b, byte [rbx] ; r10b = D
add bl, byte 2
mov r9b, byte [rbx] ; r9b = Y
mov rbx, rsi ; [rbx] = data[0]
add bl, r10b ; [rbx] = data[D]
add bl, r9b ; [rbx] = data[D + Y]
mov arg1, byte [rbx] ; arg1 = [data[D + Y]]

two_pick_instruction:

cmp al, 0x0 ; sprawdzenie, czy instrukcja to MOV
je mov_i

cmp al, 0x2 ; sprawdzenie, czy instrukcja to OR
je or_i
cmp al, 0x4 ; sprawdzenie, czy instrukcja to ADD
je add_i
cmp al, 0x5 ; sprawdzenie, czy instrukcja to SUB
je sub_i
cmp al, 0x6 ; sprawdzenie, czy instrukcja to ADC
je adc_i
cmp al, 0x7 ; sprawdzenie, czy instrukcja to SBB
je sbb_i
cmp al, 0x8 ; sprawdzenie, czy instrukcja to XCHG
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
mov [rbx], arg1
inc byte PC
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
jnz adc_check_C_flag
mov Z, byte 1
adc_check_C_flag:
jnc instruction_done
mov C, byte 1
jmp instruction_done

sbb_i:
mov Z, byte 0
mov C, byte 0
sbb arg1, arg2
jnz sbb_check_C_flag
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
jnz cmpi_check_C_flag
mov Z, byte 1
cmpi_check_C_flag:
jnc instruction_done
mov C, byte 1
jmp instruction_done

rcr_i:
mov r9b, arg1 ; r9b będzie następnym C
and r9b, 01
cmp C, byte 1
jnz rcr_i_dont_set_CF
stc
jmp rcr_i_shift
rcr_i_dont_set_CF:
clc
rcr_i_shift:
rcr arg1, 1
mov C, byte r9b
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

pop r15
pop r14
pop r13
pop r12
pop rbx

ret