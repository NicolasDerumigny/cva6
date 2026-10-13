#include <cstddef>
#include <cstdint>
#include <cstdio>

constexpr uint64_t MEM_OFFSET = 0x80000000;
constexpr uint64_t WORDLEN_BYTE = 8;
constexpr size_t MEM_SIZE = (1ULL << 25) * 8;

extern "C" void emulate_syscall(long long tohost, long long fromhost);

class SyscallHandler {
  static uintptr_t _mem;
  static size_t _size;

  static bool is_ram_addr(uint64_t addr) {
    return addr >= MEM_OFFSET && addr - MEM_OFFSET < _size;
  }

public:
  static void init(void *mem, size_t size = MEM_SIZE);
  static void emulate_syscall(long long tohost, long long fromhost);
};
