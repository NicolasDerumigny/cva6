/* CLASS = S */
/*
c  This file is generated automatically by the setparams utility.
c  It sets the number of processors and the class of the NPB
c  in this directory. Do not modify it by hand.
*/

/* full problem size */
#define	ISIZ1	12
#define	ISIZ2	12
#define	ISIZ3	12
/* number of iterations and how often to print the norm */
#define	ITMAX_DEFAULT	50
#define	INORM_DEFAULT	50
#define	DT_DEFAULT	0.5
#define	CONVERTDOUBLE	FALSE
#define COMPILETIME "04 Jun 2026"
#define NPBVERSION "3.0 structured"
#define CS1 "riscv64-linux-gnu-gcc"
#define CS2 "riscv64-linux-gnu-gcc"
#define CS3 "-lm $(PAPI_LIB) -static -lpapi -lpfm -lpthread"
#define CS4 "-I../common"
#define CS5 "-O2 -fopenmp -static -mcmodel=medany $(PAPI..."
#define CS6 "-O2 -fopenmp -static -mcmodel=medany"
#define CS7 "randdp"
