; SO_EMULATOR - Kamil Bugała (kb417522)
; Konwencja: parsujemy każdą instrukcję i ją wykonujemy, powtarzamy to $steps$ razy.
; W komentarzach będę opisywał rejestry A, D, X, Y jako rejestry SO,
;   aby nie myliły się ze zwykłymi rejestrami assemblerowymi.
; Młodszy bajt będzie oznaczał bajt mniej znaczący, a starszy - bardziej.

global so_emul

%ifndef CORES                     ; argument CORES programu
%define CORES 4
%endif

%macro compare_jump_less 3        ; arg1 = value1, arg2 = value2, arg3 = label do skoku
  cmp %1, %2                      ; porównanie dwóch wartości
  jb %3                           ; jeżeli arg1 < arg2, wykonujemy skok
%endmacro

%macro compare_jump_equal 3       ; arg1 = value1, arg2 = value2, arg3 = label do skoku
  cmp %1, %2                      ; porównanie dwóch wartości
  je %3                           ; jeżeli arg1 = arg2, , wykonujemy skok
%endmacro

%define CORES_NUMBER r12
%define REGISTERS_POINTER r10
%define arg1 [rbx]                ; argument pierwszy funkcji SO emulatora jako pointer
%define arg2 r15b                 ; argument drugi funkcji SO emulatora jako wartość
%define arg2_p r15                ; argument drugi funkcji SO emulatora jako pointer
%define imm8 r15b                 ; argument drugi funkcji SO emulatora jako wartość

%define A [REGISTERS_POINTER + CORES_NUMBER * 8]
%define D [REGISTERS_POINTER + CORES_NUMBER * 8 + 1]
%define X [REGISTERS_POINTER + CORES_NUMBER * 8 + 2]
%define Y [REGISTERS_POINTER + CORES_NUMBER * 8 + 3]
%define PC [REGISTERS_POINTER + CORES_NUMBER * 8 + 4]
%define UNUSED [REGISTERS_POINTER + CORES_NUMBER * 8 + 5]
%define C [REGISTERS_POINTER + CORES_NUMBER * 8 + 6]
%define Z [REGISTERS_POINTER + CORES_NUMBER * 8 + 7]

section .bss

state resq CORES
registers resq CORES              ; rejestry dla każdego rdzenia

section .text

set_argument:                             ; w al znajduje się kod zmiennej
  xor rbx, rbx                            ; zerowanie rbx, w nim będzie wskaźnik na zmienną
  xor r9, r9                              ; zerowanie pomocniczej zmiennej
  compare_jump_less al, 4, .arg_0_1_2_3   ; jeżeli kod < 4, przypisanie A, D, X, lub Y
  compare_jump_equal al, 4, .arg_4_6      ; jeżeli kod = 4, przypisanie [X]
  compare_jump_equal al, 5, .arg_5_7      ; jeżeli kod = 5, przypisanie [Y]
  mov bl, D                               ; dodanie do bl wartości rejestru D
  compare_jump_equal al, 6, .arg_4_6      ; jeżeli kod = 6, przypisanie [D + X]
  jmp .arg_5_7                            ; jeżeli kod = 7, przypisanie [D + Y]
.arg_0_1_2_3:
  lea rbx, [rel registers]                 ; przypisanie do rbx adresu do tablicy  rejestrów SO
  mov r9, CORES_NUMBER                    ; przypisanie do r9 numer rdzenia
	shl r9, 3                               ; pomnożenie razy 8
	add rbx, r9
  lea rbx, [rbx + rax]                    ; przypisanie do rbx adresu na rejestry A, D, X, lub Y
  ret                             ; zwrócenie wyniku w rbx
.arg_4_6:
  lea r9, X                       ; przypisanie do r9 adresu na rejestr SO = X
  jmp .get_data_pointer
.arg_5_7:
  lea r9, Y                       ; przypisanie do r9 adresu na rejestr SO = Y
.get_data_pointer:
  add bl, byte [r9]               ; dodanie do bl wartości rejestru SO, X, Y, X + D lub Y + D
  lea rbx, [rsi + rbx]            ; przypisanie do rbx adresu do [X], [Y], [X + D] lub [Y + D]
  ret                             ; zwrócenie wyniku w rbx

set_arg1_and_imm8:                ; ustawienie argumentów dla funkcji typu arg1, imm8
  xor rax, rax                    ; zerowanie rax, w nim przekażemy kod zmiennej
  mov arg2, byte cl               ; przypisanie wartości arg2 z młodszego bajtu instrukcji
  mov al, byte ch                 ; przypisanie do al starszego bajtu instrukcji
  and al, 7                       ; operacja % 8, w ten sposób otrzymujemy kod zmiennej arg1
  call set_argument               ; ustawiamy arg1 na podstawie kodu w al
  ret                             ; arg1 oraz imm8 są ustawione

set_arg1_and_arg2:                ; ustawienie argumentów dla funkcji typu arg1, arg2
  xor rax, rax                    ; w al przekażemy kod zmiennej arg2
  mov al, byte ch                 ; przypisanie do al starszego bajtu instrukcji
  shr al, 3                       ; operacja / 8, otrzymanie kodu zmiennej arg2 w al
  call set_argument
  mov arg2, byte [rbx]            ; przypisanie do arg2 wyniku funkcji
  xor rax, rax                    ; w al przekażemy kod zmiennej arg1
  mov al, byte ch                 ; przypisanie do al starszego bajtu instrukcji
  and al, 7                       ; operacja % 8, otrzymanie kodu zmiennej arg1 w al
  call set_argument
  ret                             ; arg1 oraz arg2 są ustawione

set_arg1_and_arg2_reference:      ; analogiczna sytuacja, jak wyżej
  xor rax, rax
  xor rbx, rbx
  mov al, byte ch
  shr al, 3                       ; operacja / 8
  call set_argument
  mov arg2_p, rbx                 ; do arg2_p przekazujemy pointer
  xor rax, rax
  mov al, byte ch
  and al, 7                       ; operacja % 8
  call set_argument
  ret                             ; arg1 oraz arg2 są ustawione

so_emul:
	lea r10, [rel registers]
  push rbx                        ; wstawienie elementów na stos, aby zachować abi
  push r12
  push r13
  push r14
  push r15

  xor rbx, rbx                    ; wyzerowanie rejestrów
  xor r12, r12
  xor r13, r13
  xor r14, r14
  xor r15, r15

  mov CORES_NUMBER, rcx           ; ilość rdzeni trzymana w r13
  mov r13, rdx                    ; ilość instrukcji trzymana w r13
  xor rbx, rbx
  xor rcx, rcx

  cmp r13, 0                      ; sprawdzenie, czy steps jest równe 0
  jne instruction_loop            ; jeśli nie, przechodzimy do pętli
  jmp end                         ; jeśli tak, wychodzimy z funkcji

instruction_loop:                 ; główna pętla funkcji
  xor rax, rax                    ; zerowanie rejestrów
  xor rbx, rbx
  xor r9, r9

  mov r9b, PC                     ; przypisanie do r9b aktualnego numeru instrukcji
  mov cx, [rdi + 2 * r9]          ; wczytanie instrukcji z argumentu *code
  xor r9, r9
  inc byte PC                     ; zmiana PC, aby wskazywał na następną instrukcję

  cmp cx, 0x4000                  ; sprawdzenie, czy instrukcja jest typu arg1, arg2
  jb .arg1_and_arg2               ; jeżeli tak, przeskakujemy

.arg1_and_imm8:
call set_arg1_and_imm8                               ; ustawiamy odpowiednio parametry arg1 i arg2
  compare_jump_equal word cx, word 0x8000, clc_i     ; sprawdzenie i skok do instrukcji CLC
  compare_jump_equal word cx, word 0x8100, stc_i     ; sprawdzenie i skok do instrukcji STC
  compare_jump_equal word cx, word 0xffff, end       ; sprawdzenie i skok do wyjścia z funkcji
  compare_jump_equal byte ch, byte 0xc0, jmp_i       ; sprawdzenie i skok do instrukcji JMP
  compare_jump_equal byte ch, byte 0xc2, jnc_i       ; sprawdzenie i skok do instrukcji JNC
  compare_jump_equal byte ch, byte 0xc3, jc_i        ; sprawdzenie i skok do instrukcji JC
  compare_jump_equal byte ch, byte 0xc4, jnz_i       ; sprawdzenie i skok do instrukcji JNZ
  compare_jump_equal byte ch, byte 0xc5, jz_i        ; sprawdzenie i skok do instrukcji JZ
  compare_jump_less byte ch, 0x48, movi_i            ; sprawdzenie i skok do instrukcji MOVI
  compare_jump_less byte ch, 0x58, ignore            ; sprawdzenie i zignorowanie instrukcji
  compare_jump_less byte ch, 0x60, xori_i            ; sprawdzenie i skok do instrukcji XORI
  compare_jump_less byte ch, 0x68, addi_i            ; sprawdzenie i skok do instrukcji ADDI
  compare_jump_less byte ch, 0x70, cmpi_i            ; sprawdzenie i skok do instrukcji CMPI
  compare_jump_less byte ch, 0x78, check_rcr_i       ; sprawdzenie i skok do sprawdzenia RCR
  jmp ignore                                         ; zignorowanie instrukcji
.arg1_and_arg2:
call set_arg1_and_arg2
  compare_jump_equal byte cl, 0x0, mov_i             ; sprawdzenie i skok do instrukcji MOV
  compare_jump_equal byte cl, 0x2, or_i              ; sprawdzenie i skok do instrukcji OR
  compare_jump_equal byte cl, 0x4, add_i             ; sprawdzenie i skok do instrukcji ADD
  compare_jump_equal byte cl, 0x5, sub_i             ; sprawdzenie i skok do instrukcji SUB
  compare_jump_equal byte cl, 0x6, adc_i             ; sprawdzenie i skok do instrukcji ADC
  compare_jump_equal byte cl, 0x7, sbb_i             ; sprawdzenie i skok do instrukcji SBB
call set_arg1_and_arg2_reference
  compare_jump_equal byte cl, 0x8, xchg_i            ; sprawdzenie i skok do instrukcji XCHG
  jmp ignore                                         ; zignorowanie instrukcji
ignore:
instruction_done:                                    ; instrukcja została wykonana
  xor rbx, rbx                                       ; wyzerowanie rejestrów
  xor r15, r15
  xor r9, r9
  inc r14                         ; zwiększenie licznika wykonanych instrukcji
  cmp r14, r13                    ; sprawdzamy, czy wykonaliśmy już steps instrukcji
  jne instruction_loop            ; jeśli nie, to parsujemy i wykonujemy kolejną
  jmp end                         ; jeśli tak, kończymy funkcję

check_rcr_i:                      ; sprawdzenie poprawności RCR
  compare_jump_equal cl, 0x1, rcr_i
  jmp ignore

mov_i:                            ; instrukcja MOV
  mov byte arg1, byte arg2
  jmp instruction_done

or_i:                             ; instrukcja OR
  or byte arg1, byte arg2
  call set_Z_flag                 ; ustawienie flagi Z
  jmp instruction_done

add_i:                            ; instrukcja ADD
  add byte arg1, byte arg2
  call set_Z_flag                 ; ustawienie flagi Z
  jmp instruction_done

sub_i:                            ; instrukcja SUB
  sub byte arg1, byte arg2
  call set_Z_flag                 ; ustawienie flagi Z
  jmp instruction_done

adc_i:                            ; instrukcja ADC
  call get_C_flag                 ; pobranie flagi C
  adc arg1, arg2
  call set_both_flags             ; ustawienie flagi Z i C
  jmp instruction_done

sbb_i:                            ; instrukcja SBB
  call get_C_flag                 ; pobranie flagi C
  sbb byte arg1, byte arg2        ; wykonanie instrukcji SBB
  call set_both_flags             ; ustawienie flagi Z i C
  jmp instruction_done

xchg_i:                           ; instrukcja XCHG
  xor r9, r9
  mov r9b, byte [r15]
  xchg byte [rbx], r9b
  mov byte [r15], r9b
  jmp instruction_done

movi_i:                           ; instrukcja MOVI
  mov byte arg1, byte imm8
  jmp instruction_done

xori_i:                           ; instrukcja XORI
  xor byte arg1, byte imm8
  call set_Z_flag                 ; ustawienie flagi Z
  jmp instruction_done

addi_i:                           ; instrukcja ADDI
  add byte arg1, byte imm8
  call set_Z_flag
  jmp instruction_done

cmpi_i:                           ; instrukcja CMPI
  cmp byte arg1, byte imm8
  call set_both_flags             ; ustawienie flagi Z i C
  jmp instruction_done

rcr_i:                            ; instrukcja RCR
  call get_C_flag
  rcr byte arg1, 1
  call set_C_flag                 ; ustawienie flagi C
  jmp instruction_done

clc_i:                            ; instrukcja CLC
  mov byte C, byte 0
  jmp instruction_done

stc_i:                            ; instrukcja STC
  mov byte C, byte 1
  jmp instruction_done

jnc_i:                            ; instrukcja JNC
  cmp byte C, byte 1
  je instruction_done
  jmp make_jump

jc_i:                             ; instrukcja JC
  cmp byte C, byte 1
  jne instruction_done
  jmp make_jump

jnz_i:                            ; instrukcja JNZ
  cmp byte Z, byte 1
  je instruction_done
  jmp make_jump

jz_i:                             ; instrukcja JZ
  cmp byte Z, byte 1
  jne instruction_done
  jmp make_jump

jmp_i:                            ; instrukcja JMP
make_jump:
  add byte PC, byte imm8
  jmp instruction_done

set_Z_flag:           ; ustawienie flagi Z
  lahf                ; wczytanie do rejestru ah flagi assemblerowe
  shr ah, 6           ; przesunięcie ah o 6 bitów, w ten sposób w na ostatnim bicie jest flaga ZF
  and ah, 1           ; operacja modulo 2, aby ah miało wartość 0 lub 1
  mov al, ah
  mov Z, al           ; aktualizacja flagi Z
  ret

get_C_flag:
	mov al, byte C
  mov ah, al          ; wczytanie do rejestru ah wartość flagi C
  sahf                ; aktualizacja flag assemblerowych
  ret

set_C_flag:           ; ustawienie flagi C
  lahf                ; wczytanie do rejestru ah flagi assemblerowe, na ostatnim bicie jest flaga CF
  and ah, 1           ; operacja modulo 2, aby ah miało wartość 0 lub 1
  mov al, ah
  mov C, al           ; aktualizacja flagi C
  ret

set_both_flags:       ; ustawienie obu flag C i Z
  pushf
  call set_Z_flag     ; ustawienie flagi Z
  popf
  call set_C_flag     ; ustawienie flagi C
  ret

brk_i:
end:                            ;zakończenie działania funkcji
  mov rax, A                    ;wypełnienie rax wszystkimi elementami struktury
  mov rcx, r12                  ; przywrócenie argumentu funkcji
  mov rdx, r13                  ; przywrócenie argumentu funkcji
  pop r15                       ; zwrócenie rejestrów, aby zachować ABI
  pop r14
  pop r13
  pop r12
  pop rbx
  ret