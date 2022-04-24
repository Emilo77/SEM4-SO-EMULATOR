global so_emul

%ifndef CORES
%define CORES 4
%endif

%macro compare_jump_less 3 ; arg1 = register, arg2 = value, arg3 = label
  cmp %1, %2
  jb %3
%endmacro

%macro compare_jump_equal 3 ; arg1 = register, arg2 = value, arg3 = label
  cmp %1, %2
  je %3
%endmacro

%macro instruction_or_ignore 3 ; arg1 = register, arg2 = value, arg3 = label
  compare_jump_equal %1, %2, %3
  jmp ignore
%endmacro

%macro compare_codes 6
%1:
	cmp %2, %3
	jne %4
	add bl, %5
	jmp %6
%endmacro

%define arg1_code r11b
%define arg2_code r10b
%define arg1 [rbx]
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

section .data

; Blokada otwarta ma wartość 0. Blokada zamknięta ma wartość 1.
align 4
spin_lock dd 0

section .bss

state resq CORES
registers resb 8

section .text
so_emul:
	push rbx
	push r12
	push r13
	push r14
	push r15

	xor r12, r12
	xor r13, r13
	xor r14, r14 ; index pierwszego argumentu
	xor r15, r15 ; index drugiego argumentu lub imm8

	mov r12, rcx ; ilość rdzeni trzymana w r12
	mov r13, rdx ; ilość instrukcji trzymana w r13
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx

	cmp r13, 0 ; sprawdzenie, czy liczba instrukcji jest równa 0
	jne instruction_loop ; jeśli nie, przechodzimy do pętli
	jmp end ; jeśli tak, wychodzimy z programu

instruction_loop:
	xor arg2, arg2 ; zerowanie argumentów funkcji
	xor rbx, rbx
	xor r9, r9
	mov r9b, PC
	inc byte PC
	mov ax, word [rdi + 2 * r9] ; pobieramy instrukcję

	cmp ah, 0x40 ; sprawdzenie, czy to instrukcja dwuargumentowa
	jb check_two_args_i ; jeśli tak, to sprawdzamy która dokładnie

	mov arg2, byte al ; pobieramy drugi argument
	mov dl, byte ah
	mov arg1_code, byte dl
	and arg1_code, 7 ; and arg1_code, 00000111
;	shr dl, 3
;	shl dl, 3
;	sub arg1_code, dl ; arg1_code = {0, 1, 2, 3, 4, 5, 6, 7}

	cmp arg1_code, 3
	ja data_changing

	mov rbx, registers
	add bl, byte arg1_code ; rbx = registers + arg1_code
	jmp pick_instruction

data_changing:
	mov rbx, rsi

arg1_code_4:
	cmp arg1_code, 4
	jne arg1_code_5
	add bl, byte X
	jmp pick_instruction

arg1_code_5:
	cmp arg1_code, 5
	jne arg1_code_6
	add bl, byte Y
	jmp pick_instruction

arg1_code_6:
	cmp arg1_code, 6
	jne arg1_code_7
	add bl, byte X
	add bl, byte D
	jmp pick_instruction

arg1_code_7:
	add bl, byte Y
	add bl, byte D

pick_instruction:
	compare_jump_less ah, 0x48, movi_i
	compare_jump_less ah, 0x58, ignore
	compare_jump_less ah, 0x60, xori_i
	compare_jump_less ah, 0x68, addi_i
	compare_jump_less ah, 0x70, cmpi_i
	compare_jump_less ah, 0x78, check_rcr
	compare_jump_equal ah, 0x80, check_clc
	compare_jump_equal ah, 0x81, check_stc
	compare_jump_equal ah, 0xc0, jmp_i
	compare_jump_equal ah, 0xc2, jnc_i
	compare_jump_equal ah, 0xc3, jc_i
	compare_jump_equal ah, 0xc4, jnz_i
	compare_jump_equal ah, 0xc5, jz_i
	compare_jump_equal ah, 0xff, check_brk
	jmp ignore ; jeśli jest niepoprawna, ignorujemy

check_two_args_i:
	mov dl, byte ah
	mov arg1_code, byte dl
	mov arg2_code, dl
	shr arg2_code, 3  ; arg2_code = {0, 1, 2, 3, 4, 5, 6, 7}
	and arg1_code, 7 ; and arg1, 00000111 arg1_code = {0, 1, 2, 3, 4, 5, 6, 7}

	cmp arg2_code, 3
	ja two_arg2_set_data

	mov rbx, registers
	add bl, arg2_code
	jmp two_set_arg1

two_arg2_set_data:
		mov rbx, rsi

two_arg2_code_4:
	cmp arg2_code, 4
	jne two_arg2_code_5
	add bl, byte X
	jmp two_set_arg1

two_arg2_code_5:
	cmp arg2_code, 5
	jne two_arg2_code_6
	add bl, byte Y
	jmp two_set_arg1

two_arg2_code_6:
	cmp arg2_code, 6
	jne two_arg2_code_7
	add bl, byte X
	add bl, byte D
	jmp two_set_arg1

two_arg2_code_7:
	add bl, byte Y
	add bl, byte D

two_set_arg1:
	mov arg2, byte [rbx] ; arg2 = [data[Y + D]]
	xor rbx, rbx

	cmp arg1_code, 3
	ja two_arg1_set_data

	mov rbx, registers
	add bl, byte arg1_code ; rbx = registers + arg1_code
	jmp two_pick_instruction

two_arg1_set_data:
	mov rbx, rsi

two_arg1_code_4:
	cmp arg1_code, 4
	jne two_arg1_code_5
	add bl, byte X
	jmp two_pick_instruction

two_arg1_code_5:
	cmp arg1_code, 5
	jne two_arg1_code_6
	add bl, byte Y
	jmp two_pick_instruction

two_arg1_code_6:
	cmp arg1_code, 6
	jne two_arg1_code_7
	add bl, byte X
	add bl, byte D
	jmp two_pick_instruction

two_arg1_code_7:
	add bl, byte Y
	add bl, byte D

two_pick_instruction:
	compare_jump_equal al, 0x0, mov_i
	compare_jump_equal al, 0x2, or_i
	compare_jump_equal al, 0x4, add_i
	compare_jump_equal al, 0x5, sub_i
	compare_jump_equal al, 0x6, adc_i
	compare_jump_equal al, 0x7, sbb_i
	compare_jump_equal al, 0x8, xchg_i
	jmp ignore

check_rcr:
	instruction_or_ignore al, 0x1, rcr_i
check_clc:
	instruction_or_ignore al, 0x0, clc_i
check_stc:
	instruction_or_ignore al, 0x0, stc_i
check_brk:
	instruction_or_ignore al, 0xff, end
ignore:
instruction_done:
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
	jnz .adc_check_C_flag
	mov Z, byte 1
.adc_check_C_flag:
	jnc instruction_done
	mov C, byte 1
	jmp instruction_done

sbb_i:
	mov Z, byte 0
	mov C, byte 0
	sbb arg1, arg2
	jnz .sbb_check_C_flag
	mov Z, byte 1
.sbb_check_C_flag:
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
	jnz .cmpi_check_C_flag
	mov Z, byte 1
.cmpi_check_C_flag:
	jnc instruction_done
	mov C, byte 1
	jmp instruction_done

rcr_i:
	mov r9b, arg1 ; r9b będzie następnym C
	and r9b, 01
	cmp C, byte 1
	jnz .rcr_i_dont_set_CF
	stc
	jmp .rcr_i_shift
.rcr_i_dont_set_CF:
	clc
.rcr_i_shift:
	rcr byte arg1, byte 1
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

xchg_i:
	mov r9d, 1
busy_wait:
;  xor rdx, rdx        ; W eax jest wartość otwartej blokady.
;  lock cmpxchg [rdx], r9d      ; Jeśli blokada otwarta, zamknij ją.
;	jne busy_wait       ; Skocz, gdy blokada była zamknięta.
	xchg arg1, arg2
;  mov [rdx], eax      ; Otwórz blokadę.
;	jmp instruction_done

end:
	mov rax, [rel registers] ;wypełnienie rax wszystkimi elementami struktury
	mov rcx, r12 ; przywrócenie argumentu funkcji
  mov rdx, r13 ; przywrócenie argumentu funkcji
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx

ret