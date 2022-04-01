#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <pthread.h>

#ifndef CORES
#define CORES 4
#endif

#define MEM_SIZE 256

typedef struct __attribute__((packed)) {
  uint8_t A, D, X, Y, PC;
  uint8_t unused; // Wypełniacz, aby struktura zajmowała 8 bajtów.
  bool    C, Z;
} cpu_state_t;

// Tak zadeklarowaną funkcję można wywoływać też dla procesora jednordzeniowego.
cpu_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps, size_t core);

static void dump_cpu_state(size_t core, cpu_state_t cpu_state, uint8_t const *data) {
  printf("core %zu: A = %02" PRIx8 ", D = %02" PRIx8 ", X = %02" PRIx8 ", Y = %02"
         PRIx8 ", PC = %02" PRIx8 ", C = %hhu, Z = %hhu, [X] = %02" PRIx8 ", [Y] = %02"
         PRIx8 ", [X + D] = %02" PRIx8 ", [Y + D] = %02" PRIx8 "\n",
         core, cpu_state.A, cpu_state.D, cpu_state.X, cpu_state.Y, cpu_state.PC,
         cpu_state.C, cpu_state.Z, data[cpu_state.X], data[cpu_state.Y],
         data[(cpu_state.X + cpu_state.D) & 0xFF], data[(cpu_state.Y + cpu_state.D) & 0xFF]);
}

static void dump_memory(uint8_t const *memory) {
  for (unsigned i = 0; i < MEM_SIZE; ++i) {
    printf("%02" PRIx8, memory[i]);
    unsigned r = i & 0xf;
    if (r == 7)
      printf("  ");
    else if (r == 15)
      printf("\n");
    else
      printf(" ");
  }
}

// Sprawdza proste przypisania bez skoków.
static const uint16_t code_mov[MEM_SIZE] = {
  0x4000 + 0x100 * 0 + 1,           // MOVI A, 1
  0x4000 + 0x100 * 1 + 3,           // MOVI D, 3
  0x4000 + 0x100 * 2 + 0x11,        // MOVI X, 0x11
  0x4000 + 0x100 * 3 + 0x21,        // MOVI Y, 0x21
  0x0000 + 0x100 * 4 + 0x0800 * 0,  // MOV  [X], A
  0x0000 + 0x100 * 5 + 0x0800 * 1,  // MOV  [Y], D
  0x4000 + 0x100 * 6 + 0x07,        // MOVI [X + D], 0x07
  0x0004 + 0x100 * 1 + 0x0800 * 0,  // ADD  D, A
  0x4000 + 0x100 * 6 + 0x08,        // MOVI [X + D], 0x08
  0x0000 + 0x100 * 7 + 0x0800 * 6,  // MOV  [Y + D], [X + D]
  0x0000                            // MOV  A, A; czyli NOP
};

// Mnoży wartości z komórek pamięci o adresach 0 i 1. Umieszcza wynik
// w komórkach pamięci o adresach 0 i 1 w porządku grubokońcówkowym.
// Bardzo podobnie wygląda mikrokod procesora 8086 realizujący mnożenie,
// patrz U.S. Patent No. 4,449,184.
static const uint16_t code_mul[MEM_SIZE] = {
  0x4000 + 0x100 * 2 + 1,           // MOVI X, 1
  0x4000 + 0x100 * 3 + 0,           // MOVI Y, 0
  0x0000 + 0x100 * 0 + 0x0800 * 5,  // MOV  A, [Y]
  0x4000 + 0x100 * 5 + 0,           // MOVI [Y], 0
  0x4000 + 0x100 * 1 + 8,           // MOVI D, 8
  0x7001 + 0x100 * 4,               // RCR  [X]
  0xC200 + 2,                       // JNC  +2
  0x8000,                           // CLC
  0x0006 + 0x100 * 5 + 0x0800 * 0,  // ADC  [Y], A
  0x7001 + 0x100 * 5,               // RCR  [Y]
  0x7001 + 0x100 * 4,               // RCR  [X]
  0x6000 + 0x100 * 1 + 255,         // ADDI D, -1
  0xC400 + (uint8_t)-7,             // JNZ  -7
  0xC000                            // MOV  A, A; czyli NOP
};

// Atomowe zwiększanie wspólnej 32-bitowej zmiennej globalnej przez równolegle
// uruchomione rdzenie. Wartość parametru addr jest ustalana indywidualnie dla
// każdego rdzenia przy uruchamianiu procesora.
static const uint16_t code_inc[MEM_SIZE] = {
  0x4000 + 0x100 * 3,               // MOVI Y, addr
  0xC000 + 18,                      // JMP  +18

  0x4000 + 0x100 * 0 + 1,           // MOVI A, 1
  0x4000 + 0x100 * 2 + 5,           // MOVI X, 5
  0x0008 + 0x100 * 4 + 0x0800 * 0,  // XCHG [X], A
  0x6800 + 0x100 * 0 + 0,           // CMPI A, 0
  0xC400 + (uint8_t)-3,             // JNZ  -3

  0x4000 + 0x100 * 2 + 255,         // MOVI X, 255
  0x4000 + 0x100 * 1 + 4,           // MOVI D, 4
  0x8100,                           // STC
  0x0006 + 0x100 * 6 + 0x0800 * 0,  // ADC  [X + D], A
  0x6000 + 0x100 * 1 + 255,         // ADDI D, -1
  0xC400 + (uint8_t)-3,             // JNZ  -3

  0x4000 + 0x100 * 2 + 5,           // MOVI X, 5
  0x0000 + 0x100 * 4 + 0x0800 * 0,  // MOV [X], A

  0x4000 + 0x100 * 1 + 4,           // MOVI D, 4
  0x8100,                           // STC
  0x0007 + 0x100 * 7 + 0x0800 * 0,  // SBB  [Y + D], A
  0x6000 + 0x100 * 1 + 255,         // ADDI D, -1
  0xC400 + (uint8_t)-3,             // JNZ  -3

  0x4000 + 0x100 * 1 + 4,           // MOVI D, 4
  0x0000 + 0x100 * 0 + 0x0800 * 7,  // MOV  A, [Y + D]
  0x6000 + 0x100 * 1 + 255,         // ADDI D, -1
  0x0002 + 0x100 * 0 + 0x0800 * 7,  // OR   A, [Y + D]
  0x6000 + 0x100 * 1 + 255,         // ADDI D, -1
  0xC400 + (uint8_t)-3,             // JNZ  -3

  0x6800 + 0x100 * 0 + 0,           // CMPI A, 0
  0xC400 + (uint8_t)-26,            // JNZ  -26
  0xFFFF                            // BRK
};

static uint8_t data[MEM_SIZE];

// PRZYKŁADY Z JEDNYM RDZENIEM

static void single_core_simple_test(void) {
  dump_cpu_state(0, so_emul(code_mov, data, 4, 0), data);
  dump_cpu_state(0, so_emul(code_mov, data, 7, 0), data);
  dump_memory(data);
}

static void single_core_mul_test(uint8_t a, uint8_t b) {
  cpu_state_t cpu_state;

  data[0] = a;
  data[1] = b;
  dump_memory(data);

  // Kod można wykonywać krokowo.
  dump_cpu_state(0, cpu_state = so_emul(code_mul, data, 0, 0), data);
  while (cpu_state.PC != 13) {
    dump_cpu_state(0, cpu_state = so_emul(code_mul, data, 1, 0), data);
  }

  dump_memory(data);
}

// PRZYKŁAD Z WIELOMA RDZENIAMI

typedef struct {
  size_t         core;
  size_t         steps;
  uint16_t const *code;
  cpu_state_t    state;
} core_test_data_t;

// Wszystkie rdzenie powinny wystartować równocześnie.
volatile int wait = 0;

static void * core_thread(void *param) {
  core_test_data_t *ctd = (core_test_data_t *)param;

  // Każdy rdzeń dostaje inny adres parametru count.
  // Tu zakładamy, że rdzeni jest co najwyżej 62.
  uint16_t local_code[MEM_SIZE];
  memcpy(local_code, ctd->code, sizeof local_code);
  local_code[0] |= ((4 * ctd->core + 7) & 0xff);

  // Wszystkie rdzenie powinny wystartować równocześnie.
  while (wait == 0);

  ctd->state = so_emul(local_code, data, ctd->steps, ctd->core);

  return NULL;
}

static void multi_core_inc_test(uint32_t count) {
  pthread_t tid[CORES];
  core_test_data_t ctd[CORES];

  // Każdy rdzeń dostaje parametr count pod innym adresem w pamięci.
  // Wartość jest zapisywana w porządku grubońcówkowym.
  // Tu zakładamy, że rdzeni jest co najwyżej 62.
  assert(CORES <= 62);
  data[8]  = count >> 24;
  data[9]  = (count >> 16) & 0xff;
  data[10] = (count >> 8) & 0xff;
  data[11] = count & 0xff;
  for (size_t i = 1; i < CORES; ++i) {
    data[8  + 4 * i] = data[8];
    data[9  + 4 * i] = data[9];
    data[10 + 4 * i] = data[10];
    data[11 + 4 * i] = data[11];
  }
  dump_memory(data);

  for (size_t i = 0; i < CORES; ++i) {
    ctd[i].core = i;
    ctd[i].steps = SIZE_MAX; // w praktyce nieskończoność
    ctd[i].code = code_inc;
  }

  for (size_t i = 0; i < CORES; ++i)
    if (pthread_create(&tid[i], NULL, &core_thread, (void*)&ctd[i]))
      exit(1);

  wait = 1; // Wystartuj rdzenie.

  for (size_t i = 0; i < CORES; ++i)
    if (pthread_join(tid[i], NULL))
      exit(1);

  for (size_t i = 0; i < CORES; ++i)
    dump_cpu_state(i, ctd[i].state, data);
  dump_memory(data);
}

// WYBÓR PRZYKŁADU

int main(int argc, char *args[]) {
  if (argc == 1)
    single_core_simple_test();
  else if (argc == 2)
    multi_core_inc_test(strtoumax(args[1], NULL, 10));
  else if (argc == 3)
    single_core_mul_test(strtoumax(args[1], NULL, 10), strtoumax(args[2], NULL, 10));
  else
    return 1;
}
