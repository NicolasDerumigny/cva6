#ifndef TYPES_H
#define TYPES_H

#define LENGTH(array) (sizeof(array) / sizeof(array[0]))

typedef unsigned long uint64_t;
typedef unsigned int uint;

typedef void (*vec_f)(void);
typedef void (*stvec_f)(vec_f);
typedef void (*tlb_f)(void);

#endif // TYPES_H
