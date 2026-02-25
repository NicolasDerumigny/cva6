#ifndef HMODE_PANIC_H
#define HMODE_PANIC_H

#include "util.h"

__attribute__((noreturn)) void panic(void);
__attribute__((noreturn)) void panic_vector(void);

void reset(void);

#endif //HMODE_PANIC_H
