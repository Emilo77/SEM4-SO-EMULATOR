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

section .bss

state resq CORES
registers resq CORES

section .text

set_argument: ; w al znajduje się kod zmiennej
	xor rbx, rbx
	xor r8, r8
	compare_jump_less al, 4, .arg_0_1_2_3
	compare_jump_equal al, 4, .arg_4_6
	compare_jump_equal al, 5, .arg_5_7
	mov bl, D
	compare_jump_equal al, 6, .arg_4_6
	jmp .arg_5_7
.arg_0_1_2_3:
	lea rbx, [rel registers]
	lea rbx, [rbx + rax]
	ret
.arg_4_6:
	lea r8, X
	jmp .get_data_pointer
.arg_5_7:
	lea r8, Y
.get_data_pointer:
  add bl, byte [r8]
  lea rbx, [rsi + rbx]
  ret

set_arg1_and_imm8:
	xor rax, rax
	mov arg2, byte cl
	mov al, byte ch
	and al, 7 ; operacja % 8
	call set_argument
	ret

set_arg1_and_arg2:
	xor rax, rax
	mov al, byte ch
	shr al, 3 ; operacja / 8
	call set_argument
	mov arg2, byte [rbx]
	xor rax, rax
	mov al, byte ch
	and al, 7 ; operacja % 8
	call set_argument
	ret

set_arg1_and_arg2_reference:
	xor rax, rax
	xor rbx, rbx
	mov al, byte ch
	shr al, 3 ; operacja / 8
	call set_argument
	mov r15, rbx
	xor rax, rax
	mov al, byte ch
	and al, 7 ; operacja % 8
	call set_argument
	ret

so_emul:
	push rbx
	push r12
	push r13
	push r14
	push r15

	xor rbx, rbx
	xor r10, r10
	xor r12, r12
  xor r13, r13
  xor r14, r14
  xor r15, r15

  mov r12, rcx ; ilość rdzeni trzymana w r12
  mov r13, rdx ; ilość instrukcji trzymana w r13
  xor rbx, rbx
  xor rcx, rcx

  cmp r13, 0 ; sprawdzenie, czy liczba instrukcji jest równa 0
  jne instruction_loop ; jeśli nie, przechodzimy do pętli
  jmp end ; jeśli tak, wychodzimy z programu

instruction_loop:
	xor rax, rax
  xor rbx, rbx

	xor r9, r9
	mov r9b, PC
	mov cx, [rdi + 2 * r9] ; wczytujemy instrukcję z tablicy
	xor r9, r9
	inc byte PC

	cmp cx, 0x4000
	jb .arg1_and_arg2

.arg1_and_imm8:
call set_arg1_and_imm8
	compare_jump_equal word cx, word 0x8000, clc_i
  compare_jump_equal word cx, word 0x8100, stc_i
  compare_jump_equal word cx, word 0xffff, end
  compare_jump_equal byte ch, byte 0xc0, jmp_i
  compare_jump_equal byte ch, byte 0xc2, jnc_i
  compare_jump_equal byte ch, byte 0xc3, jc_i
  compare_jump_equal byte ch, byte 0xc4, jnz_i
  compare_jump_equal byte ch, byte 0xc5, jz_i
	compare_jump_less byte ch, 0x48, movi_i
	compare_jump_less byte ch, 0x58, ignore
	compare_jump_less byte ch, 0x60, xori_i
	compare_jump_less byte ch, 0x68, addi_i
	compare_jump_less byte ch, 0x70, cmpi_i
	compare_jump_less byte ch, 0x78, check_rcr_i
	jmp ignore
.arg1_and_arg2:
call set_arg1_and_arg2
	compare_jump_equal byte cl, 0x0, mov_i
	compare_jump_equal byte cl, 0x2, or_i
	compare_jump_equal byte cl, 0x4, add_i
	compare_jump_equal byte cl, 0x5, sub_i
	compare_jump_equal byte cl, 0x6, adc_i
	compare_jump_equal byte cl, 0x7, sbb_i
call set_arg1_and_arg2_reference
	compare_jump_equal byte cl, 0x8, xchg_i
	jmp ignore
ignore:
instruction_done:
	xor rbx, rbx
	xor r15, r15
	xor r9, r9
	inc r14
	cmp r14, r13                   ;sprawdzamy, czy wykonaliśmy już steps instrukcji
	jne instruction_loop           ; jeśli nie, to parsujemy i wykonujemy kolejną
	jmp end                        ; jeśli wszystkie, kończymy program

check_rcr_i:
	compare_jump_equal cl, 0x1, rcr_i
	jmp ignore

mov_i:
	mov byte arg1, byte arg2
	jmp instruction_done

or_i:
	or byte arg1, byte arg2
	call set_Z_flag
	jmp instruction_done

add_i:
	add byte arg1, byte arg2
  call set_Z_flag
	jmp instruction_done

sub_i:
	sub byte arg1, byte arg2
  call set_Z_flag
	jmp instruction_done

adc_i:
	mov byte ah, byte C
	sahf
	adc arg1, arg2
	call set_both_flags
	jmp instruction_done

sbb_i:
	mov ah, byte C
	sahf
	sbb byte arg1, byte arg2
	call set_both_flags
	jmp instruction_done

	xchg_i:
	xor r9, r9
	mov r9b, byte [r15]
  xchg byte [rbx], r9b
  mov byte [r15], r9b
  jmp instruction_done

movi_i:
	mov byte arg1, byte imm8
	jmp instruction_done

xori_i:
	xor byte arg1, byte imm8
  call set_Z_flag
  jmp instruction_done

addi_i:
	add byte arg1, byte imm8
  lahf
  call set_Z_flag
  jmp instruction_done

cmpi_i:
	cmp byte arg1, byte imm8
	call set_both_flags
  jmp instruction_done

rcr_i:
	mov ah, byte C
	sahf
	rcr byte arg1, 1
	call set_C_flag
  jmp instruction_done

clc_i:
	mov byte C, byte 0
  jmp instruction_done

stc_i:
	mov byte C, byte 1
	jmp instruction_done

jnc_i:
	cmp byte C, byte 1
	je instruction_done
	jmp make_jump

jc_i:
	cmp byte C, byte 1
	jne instruction_done
	jmp make_jump

jnz_i:
 	cmp byte Z, byte 1
 	je instruction_done
 	jmp make_jump

jz_i:
 	cmp byte Z, byte 1
 	jne instruction_done
 	jmp make_jump

jmp_i:
make_jump:
	add byte PC, byte imm8
	jmp instruction_done

set_Z_flag:
	lahf
	shr ah, 6
	and ah, 1
	mov Z, ah
	ret

set_C_flag:
	lahf
	and ah, 1
	mov C, ah
	ret

set_both_flags:
	pushf
	call set_Z_flag
	popf
	call set_C_flag
	ret

brk_i:
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