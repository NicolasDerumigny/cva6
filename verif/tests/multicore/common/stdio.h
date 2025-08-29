typedef __SIZE_TYPE__ size_t;

int printf(const char *fmt, ...);
int sprintf(char *str, const char *fmt, ...);
int putchar(int ch);
int puts(const char *s);
void *memcpy(void *dest, const void *src, size_t len);
void *memset(void *dest, int byte, size_t len);
size_t strlen(const char *s);
size_t strnlen(const char *s, size_t n);
int strcmp(const char *s1, const char *s2);
char *strcpy(char *dest, const char *src);
long atol(const char *str);
