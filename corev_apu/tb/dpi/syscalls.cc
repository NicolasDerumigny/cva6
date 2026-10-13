#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

#include "syscalls.h"

uintptr_t SyscallHandler::_mem;
size_t SyscallHandler::_size = MEM_SIZE;

void emulate_syscall(long long tohost, long long fromhost) {
  SyscallHandler::emulate_syscall(tohost, fromhost);
}

void SyscallHandler::init(void *mem, size_t size) {
  _mem = (uintptr_t)mem - MEM_OFFSET;
  _size = size;
}

void SyscallHandler::emulate_syscall(long long tohost, long long fromhost) {
  if (!is_ram_addr((uint64_t)tohost)) {
    fprintf(stderr,
            "[ERROR]: tohost value 0x%lx is not a valid address - "
            "[0x%lx, 0x%lx): not a syscall\n",
            (uint64_t)tohost, MEM_OFFSET, MEM_OFFSET + _size);
    return;
  }
  if (!is_ram_addr((uint64_t)fromhost)) {
    fprintf(stderr, "[ERROR]: fromhost address 0x%lx is not a valid address\n",
            (uint64_t)fromhost);
    return;
  }

  long long which, arg0, arg1, arg2;
  which = *(long long *)(_mem + tohost);
  arg0 = *(long long *)(_mem + tohost + WORDLEN_BYTE);
  arg1 = *(long long *)(_mem + tohost + 2 * WORDLEN_BYTE);
  arg2 = *(long long *)(_mem + tohost + 3 * WORDLEN_BYTE);
  switch (which) {
  case 64: {
    // arg1 is a guest address as well: write() would fault on an out-of-range
    // one.
    if (!is_ram_addr((uint64_t)arg1)) {
      fprintf(stderr,
              "[ERROR]: syscall write buffer address 0x%lx is outside the "
              "memory model\n",
              (uint64_t)arg1);
      break;
    }
    long ret = write((int)arg0, (void *)(_mem + arg1), (size_t)arg2);
    *((long long *)(_mem + tohost)) = ret;
    break;
  }
  default: {
    fprintf(stderr, "[ERROR]: Unknown syscall %lld\n", which);
    break;
  }
  }
  *((uint64_t *)(_mem + fromhost)) = 1;
}
