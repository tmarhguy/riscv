/*
 * Dhrystone Benchmark for IronCore RV32IM
 * Adapted for bare-metal execution
 */

#include <stdint.h>

// Performance counter access
static inline uint64_t read_cycle(void) {
    uint64_t cycles;
    asm volatile ("rdcycle %0" : "=r"(cycles));
    return cycles;
}

static inline uint64_t read_instret(void) {
    uint64_t instret;
    asm volatile ("rdinstret %0" : "=r"(instret));
    return instret;
}

// Minimal printf for results
extern void uart_puts(const char *s);
extern void uart_put_hex(uint32_t val);
extern void uart_newline(void);

// Dhrystone configuration
#define RUNS 100  // Number of Dhrystone runs

// Dhrystone types
typedef enum {Ident_1, Ident_2, Ident_3, Ident_4, Ident_5} Enumeration;

typedef int One_Thirty;
typedef int One_Fifty;
typedef char Capital_Letter;
typedef int Boolean;
typedef char Str_30[31];
typedef int Arr_1_Dim[50];
typedef int Arr_2_Dim[50][50];

typedef struct record {
    struct record *Ptr_Comp;
    Enumeration Discr;
    union {
        struct {
            Enumeration Enum_Comp;
            int Int_Comp;
            char Str_Comp[31];
        } var_1;
        struct {
            Enumeration E_Comp_2;
            char Str_2_Comp[31];
        } var_2;
        struct {
            char Ch_1_Comp;
            char Ch_2_Comp;
        } var_3;
    } variant;
} Rec_Type, *Rec_Pointer;

// Global variables
Rec_Type Rec_1, Rec_2;
int Int_Glob;
Boolean Bool_Glob;
char Ch_1_Glob, Ch_2_Glob;
int Arr_1_Glob[50];
int Arr_2_Glob[50][50];

// Forward declarations
void Proc_1(Rec_Pointer Ptr_Val_Par);
void Proc_2(One_Fifty *Int_Par_Ref);
void Proc_3(Rec_Pointer *Ptr_Ref_Par);
void Proc_4(void);
void Proc_5(void);
void Proc_6(Enumeration Enum_Val_Par, Enumeration *Enum_Ref_Par);
void Proc_7(One_Fifty Int_1_Par_Val, One_Fifty Int_2_Par_Val, One_Fifty *Int_Par_Ref);
void Proc_8(Arr_1_Dim Arr_1_Par_Ref, Arr_2_Dim Arr_2_Par_Ref, int Int_1_Par_Val, int Int_2_Par_Val);
Enumeration Func_1(Capital_Letter Ch_1_Par_Val, Capital_Letter Ch_2_Par_Val);
Boolean Func_2(Str_30 Str_1_Par_Ref, Str_30 Str_2_Par_Ref);
Boolean Func_3(Enumeration Enum_Par_Val);

// String copy
void strcpy_local(char *dst, const char *src) {
    while (*src) {
        *dst++ = *src++;
    }
    *dst = '\0';
}

// String compare
int strcmp_local(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}

int main(void) {
    One_Fifty Int_1_Loc, Int_2_Loc, Int_3_Loc;
    char Ch_Index;
    Enumeration Enum_Loc;
    Str_30 Str_1_Loc, Str_2_Loc;
    int Run_Index;
    
    uint64_t start_cycles, end_cycles;
    uint64_t start_instret, end_instret;
    
    uart_puts("\\r\\n=== Dhrystone Benchmark ===\\r\\n");
    uart_puts("Runs: ");
    uart_put_hex(RUNS);
    uart_newline();
    
    // Initialize
    Rec_1.Ptr_Comp = &Rec_2;
    Rec_1.Discr = Ident_1;
    Rec_1.variant.var_1.Enum_Comp = Ident_3;
    Rec_1.variant.var_1.Int_Comp = 40;
    strcpy_local(Rec_1.variant.var_1.Str_Comp, "DHRYSTONE PROGRAM, SOME STRING");
    strcpy_local(Str_1_Loc, "DHRYSTONE PROGRAM, 1'ST STRING");
    
    Arr_2_Glob[8][7] = 10;
    
    // Start measurement
    start_cycles = read_cycle();
    start_instret = read_instret();
    
    // Main benchmark loop
    for (Run_Index = 1; Run_Index <= RUNS; ++Run_Index) {
        Proc_5();
        Proc_4();
        Int_1_Loc = 2;
        Int_2_Loc = 3;
        strcpy_local(Str_2_Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
        Enum_Loc = Ident_2;
        Bool_Glob = !Func_2(Str_1_Loc, Str_2_Loc);
        
        while (Int_1_Loc < Int_2_Loc) {
            Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;
            Proc_7(Int_1_Loc, Int_2_Loc, &Int_3_Loc);
            Int_1_Loc += 1;
        }
        
        Proc_8(Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
        Proc_1(&Rec_1);
        
        for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index) {
            if (Enum_Loc == Func_1(Ch_Index, 'C')) {
                Proc_6(Ident_1, &Enum_Loc);
                strcpy_local(Str_2_Loc, "DHRYSTONE PROGRAM, 3'RD STRING");
                Int_2_Loc = Run_Index;
                Int_Glob = Run_Index;
            }
        }
        
        Int_2_Loc = Int_2_Loc * Int_1_Loc;
        Int_1_Loc = Int_2_Loc / Int_3_Loc;
        Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;
        Proc_2(&Int_1_Loc);
    }
    
    // End measurement
    end_cycles = read_cycle();
    end_instret = read_instret();
    
    uint64_t cycles = end_cycles - start_cycles;
    uint64_t instret = end_instret - start_instret;
    
    uart_puts("\\r\\nResults:\\r\\n");
    uart_puts("Cycles: ");
    uart_put_hex((uint32_t)(cycles >> 32));
    uart_put_hex((uint32_t)cycles);
    uart_newline();
    
    uart_puts("Instructions: ");
    uart_put_hex((uint32_t)(instret >> 32));
    uart_put_hex((uint32_t)instret);
    uart_newline();
    
    // Calculate IPC (scaled by 1000 for precision)
    uint32_t ipc_scaled = (uint32_t)((instret * 1000) / cycles);
    uart_puts("IPC (x1000): ");
    uart_put_hex(ipc_scaled);
    uart_newline();
    
    // Dhrystones per second = RUNS / (cycles / freq)
    // DMIPS/MHz = (Dhrystones/sec) / 1757 / MHz
    // For simulation, we report cycles per run
    uint32_t cycles_per_run = (uint32_t)(cycles / RUNS);
    uart_puts("Cycles/Run: ");
    uart_put_hex(cycles_per_run);
    uart_newline();
    
    uart_puts("\\r\\nDhrystone Complete!\\r\\n");
    
    return 0;
}

// Dhrystone procedures (simplified implementations)
void Proc_1(Rec_Pointer Ptr_Val_Par) {
    Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;
    *Ptr_Val_Par->Ptr_Comp = *Ptr_Val_Par;
    Ptr_Val_Par->variant.var_1.Int_Comp = 5;
    Next_Record->variant.var_1.Int_Comp = Ptr_Val_Par->variant.var_1.Int_Comp;
    Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
    Proc_3(&Next_Record->Ptr_Comp);
    if (Next_Record->Discr == Ident_1) {
        Next_Record->variant.var_1.Int_Comp = 6;
        Proc_6(Ptr_Val_Par->variant.var_1.Enum_Comp, &Next_Record->variant.var_1.Enum_Comp);
        Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
        Proc_7(Next_Record->variant.var_1.Int_Comp, 10, &Next_Record->variant.var_1.Int_Comp);
    } else {
        *Ptr_Val_Par = *Ptr_Val_Par->Ptr_Comp;
    }
}

void Proc_2(One_Fifty *Int_Par_Ref) {
    One_Fifty Int_Loc = *Int_Par_Ref + 10;
    Enumeration Enum_Loc;
    do {
        if (Ch_1_Glob == 'A') {
            Int_Loc -= 1;
            *Int_Par_Ref = Int_Loc - Int_Glob;
            Enum_Loc = Ident_1;
        }
    } while (Enum_Loc != Ident_1);
}

void Proc_3(Rec_Pointer *Ptr_Ref_Par) {
    if (Rec_1.Ptr_Comp != 0) {
        *Ptr_Ref_Par = Rec_1.Ptr_Comp;
    }
    Proc_7(10, Int_Glob, &Rec_1.variant.var_1.Int_Comp);
}

void Proc_4(void) {
    Boolean Bool_Loc = Ch_1_Glob == 'A';
    Bool_Glob = Bool_Loc | Bool_Glob;
    Ch_2_Glob = 'B';
}

void Proc_5(void) {
    Ch_1_Glob = 'A';
    Bool_Glob = 0;
}

void Proc_6(Enumeration Enum_Val_Par, Enumeration *Enum_Ref_Par) {
    *Enum_Ref_Par = Enum_Val_Par;
    if (!Func_3(Enum_Val_Par)) {
        *Enum_Ref_Par = Ident_4;
    }
    switch (Enum_Val_Par) {
        case Ident_1: *Enum_Ref_Par = Ident_1; break;
        case Ident_2: if (Int_Glob > 100) *Enum_Ref_Par = Ident_1; else *Enum_Ref_Par = Ident_4; break;
        case Ident_3: *Enum_Ref_Par = Ident_2; break;
        case Ident_4: break;
        case Ident_5: *Enum_Ref_Par = Ident_3; break;
    }
}

void Proc_7(One_Fifty Int_1_Par_Val, One_Fifty Int_2_Par_Val, One_Fifty *Int_Par_Ref) {
    One_Fifty Int_Loc = Int_1_Par_Val + 2;
    *Int_Par_Ref = Int_2_Par_Val + Int_Loc;
}

void Proc_8(Arr_1_Dim Arr_1_Par_Ref, Arr_2_Dim Arr_2_Par_Ref, int Int_1_Par_Val, int Int_2_Par_Val) {
    One_Fifty Int_Loc = Int_1_Par_Val + 5;
    Arr_1_Par_Ref[Int_Loc] = Int_2_Par_Val;
    Arr_1_Par_Ref[Int_Loc+1] = Arr_1_Par_Ref[Int_Loc];
    Arr_1_Par_Ref[Int_Loc+30] = Int_Loc;
    for (int Int_Index = Int_Loc; Int_Index <= Int_Loc+1; ++Int_Index) {
        Arr_2_Par_Ref[Int_Loc][Int_Index] = Int_Loc;
    }
    Arr_2_Par_Ref[Int_Loc][Int_Loc-1] += 1;
    Arr_2_Par_Ref[Int_Loc+20][Int_Loc] = Arr_1_Par_Ref[Int_Loc];
    Int_Glob = 5;
}

Enumeration Func_1(Capital_Letter Ch_1_Par_Val, Capital_Letter Ch_2_Par_Val) {
    Capital_Letter Ch_1_Loc = Ch_1_Par_Val;
    Capital_Letter Ch_2_Loc = Ch_1_Loc;
    if (Ch_2_Loc != Ch_2_Par_Val) {
        return Ident_1;
    } else {
        Ch_1_Glob = Ch_1_Loc;
        return Ident_2;
    }
}

Boolean Func_2(Str_30 Str_1_Par_Ref, Str_30 Str_2_Par_Ref) {
    One_Thirty Int_Loc = 2;
    Capital_Letter Ch_Loc;
    while (Int_Loc <= 2) {
        if (Func_1(Str_1_Par_Ref[Int_Loc], Str_2_Par_Ref[Int_Loc+1]) == Ident_1) {
            Ch_Loc = 'A';
            Int_Loc += 1;
        }
    }
    if (Ch_Loc >= 'W' && Ch_Loc < 'Z') {
        Int_Loc = 7;
    }
    if (Ch_Loc == 'R') {
        return 1;
    } else {
        if (strcmp_local(Str_1_Par_Ref, Str_2_Par_Ref) > 0) {
            Int_Loc += 7;
            Int_Glob = Int_Loc;
            return 1;
        } else {
            return 0;
        }
    }
}

Boolean Func_3(Enumeration Enum_Par_Val) {
    Enumeration Enum_Loc = Enum_Par_Val;
    if (Enum_Loc == Ident_3) {
        return 1;
    } else {
        return 0;
    }
}
