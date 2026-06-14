	.file	"fpu_test.c"
	.option pic
	.text
.Ltext0:
	.cfi_sections	.debug_frame
	.file 0 "/home/han4n/Documents/cva6/verif/tests/multicore/fpu_share" "fpu_test.c"
	.align	1
	.type	exact, @function
exact:
.LFB9:
	.file 1 "fpu_test.c"
	.loc 1 46 59
	.cfi_startproc
.LVL0:
	.loc 1 56 3
	.loc 1 57 3
	.loc 1 59 3
	.loc 1 59 27 is_stmt 0
	lla	a5,.LANCHOR0
	lw	a6,0(a5)
	.loc 1 60 28
	lw	a4,4(a5)
	.loc 1 61 28
	lw	a5,8(a5)
	.loc 1 59 27
	addiw	a6,a6,-1
	.loc 1 60 28
	addiw	a4,a4,-1
	.loc 1 61 28
	addiw	a5,a5,-1
	.loc 1 60 21
	fcvt.d.w	fa1,a4
	.loc 1 61 22
	fcvt.d.w	fa2,a5
	.loc 1 59 9
	fcvt.d.w	fa3,a0
	.loc 1 59 20
	fcvt.d.w	fa0,a6
	.loc 1 60 10
	fcvt.d.w	fa4,a1
	.loc 1 61 11
	fcvt.d.w	fa5,a2
	.loc 1 59 6
	fdiv.d	fa3,fa3,fa0
.LVL1:
	.loc 1 60 3 is_stmt 1
	lla	a5,.LANCHOR0+16
	lla	a4,.LANCHOR0+536
	.loc 1 60 7 is_stmt 0
	fdiv.d	fa4,fa4,fa1
.LVL2:
	.loc 1 61 3 is_stmt 1
	.loc 1 61 8 is_stmt 0
	fdiv.d	fa5,fa5,fa2
.LVL3:
	.loc 1 63 3 is_stmt 1
	.loc 1 63 17
.L2:
	.loc 1 64 5 discriminator 3
	.loc 1 64 27 is_stmt 0 discriminator 3
	fld	fa1,0(a5)
	fld	fa2,8(a5)
	.loc 1 64 43 discriminator 3
	fld	ft1,16(a5)
	.loc 1 64 60 discriminator 3
	fld	ft0,24(a5)
	.loc 1 64 27 discriminator 3
	fmadd.d	fa2,fa2,fa3,fa1
	.loc 1 65 27 discriminator 3
	fld	fa0,32(a5)
	.loc 1 65 48 discriminator 3
	fld	ft2,40(a5)
	.loc 1 66 27 discriminator 3
	fld	fa1,48(a5)
	.loc 1 65 27 discriminator 3
	fmul.d	ft5,fa3,fa0
	.loc 1 65 48 discriminator 3
	fmul.d	ft4,fa4,ft2
	.loc 1 66 52 discriminator 3
	fld	fa0,56(a5)
	.loc 1 64 43 discriminator 3
	fmadd.d	ft6,ft1,fa4,fa2
	.loc 1 66 27 discriminator 3
	fmul.d	ft3,fa5,fa1
	.loc 1 66 52 discriminator 3
	fmul.d	ft2,fa3,fa0
	.loc 1 67 27 discriminator 3
	fld	fa0,64(a5)
	.loc 1 67 56 discriminator 3
	fld	fa1,72(a5)
	.loc 1 68 28 discriminator 3
	fld	fa2,80(a5)
	.loc 1 67 27 discriminator 3
	fmul.d	ft1,fa4,fa0
	.loc 1 64 60 discriminator 3
	fmadd.d	ft6,ft0,fa5,ft6
	.loc 1 68 28 discriminator 3
	fmul.d	fa0,fa3,fa2
	.loc 1 66 57 discriminator 3
	fmul.d	ft2,ft2,fa3
	.loc 1 67 56 discriminator 3
	fmul.d	ft0,fa5,fa1
	.loc 1 69 28 discriminator 3
	fld	fa1,88(a5)
	.loc 1 70 28 discriminator 3
	fld	fa2,96(a5)
	.loc 1 67 33 discriminator 3
	fmul.d	ft1,ft1,fa4
	.loc 1 64 78 discriminator 3
	fmadd.d	ft5,ft5,fa3,ft6
	.loc 1 69 28 discriminator 3
	fmul.d	fa1,fa4,fa1
	.loc 1 68 33 discriminator 3
	fmul.d	fa0,fa0,fa3
	.loc 1 67 63 discriminator 3
	fmul.d	ft0,ft0,fa5
	.loc 1 70 28 discriminator 3
	fmul.d	fa2,fa5,fa2
	.loc 1 63 17 discriminator 3
	addi	a3,a3,8
	addi	a5,a5,104
.LVL4:
	.loc 1 65 37 discriminator 3
	fmadd.d	ft4,ft4,fa4,ft5
	.loc 1 69 34 discriminator 3
	fmul.d	fa1,fa1,fa4
	.loc 1 68 38 discriminator 3
	fmul.d	fa0,fa0,fa3
	.loc 1 70 35 discriminator 3
	fmul.d	fa2,fa2,fa5
	.loc 1 65 60 discriminator 3
	fmadd.d	ft3,ft3,fa5,ft4
	.loc 1 69 40 discriminator 3
	fmul.d	fa1,fa1,fa4
	.loc 1 70 42 discriminator 3
	fmul.d	fa2,fa2,fa5
	.loc 1 66 41 discriminator 3
	fmadd.d	ft2,ft2,fa3,ft3
	.loc 1 66 67 discriminator 3
	fmadd.d	ft1,ft1,fa4,ft2
	.loc 1 67 45 discriminator 3
	fmadd.d	ft0,ft0,fa5,ft1
	.loc 1 67 77 discriminator 3
	fmadd.d	fa0,fa0,fa3,ft0
	.loc 1 68 48 discriminator 3
	fmadd.d	fa1,fa1,fa4,fa0
	.loc 1 69 52 discriminator 3
	fmadd.d	fa2,fa2,fa5,fa1
	.loc 1 64 16 discriminator 3
	fsd	fa2,-8(a3)
	.loc 1 63 23 is_stmt 1 discriminator 3
.LVL5:
	.loc 1 63 17 discriminator 3
	bne	a4,a5,.L2
	.loc 1 72 1 is_stmt 0
	ret
	.cfi_endproc
.LFE9:
	.size	exact, .-exact
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"\n\n NAS Parallel Benchmarks 3.0 structured OpenMP C version - LU Benchmark\n"
	.text
	.align	1
	.globl	read_input
	.hidden	read_input
	.type	read_input, @function
read_input:
.LFB10:
	.loc 1 74 23 is_stmt 1
	.cfi_startproc
	.loc 1 86 3
	.loc 1 74 23 is_stmt 0
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	.loc 1 86 3
	lla	a0,.LC0
	.loc 1 74 23
	sd	ra,8(sp)
	.cfi_offset 1, -8
	.loc 1 86 3
	call	puts@plt
.LVL6:
	.loc 1 91 3 is_stmt 1
	.loc 1 92 3
	.loc 1 93 3
	.loc 1 94 3
	.loc 1 95 3
	.loc 1 96 3
	.loc 1 97 3
	.loc 1 98 3
	.loc 1 99 3
	.loc 1 100 3
	.loc 1 101 3
	.loc 1 105 1 is_stmt 0
	ld	ra,8(sp)
	.cfi_restore 1
	.loc 1 101 7
	lla	a5,.LANCHOR0
	li	a4,12
	sw	a4,0(a5)
	.loc 1 102 3 is_stmt 1
	.loc 1 102 7 is_stmt 0
	sw	a4,4(a5)
	.loc 1 103 3 is_stmt 1
	.loc 1 103 7 is_stmt 0
	sw	a4,536(a5)
	.loc 1 105 1
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE10:
	.size	read_input, .-read_input
	.section	.rodata.str1.8
	.align	3
.LC1:
	.string	"     SUBDOMAIN SIZE IS TOO SMALL - \n     ADJUST PROBLEM SIZE OR NUMBER OF PROCESSORS\n     SO THAT NX, NY AND NZ ARE GREATER THAN OR EQUAL\n     TO 4 THEY ARE CURRENTLY%3d%3d%3d\n"
	.align	3
.LC2:
	.string	"     SUBDOMAIN SIZE IS TOO LARGE - \n     ADJUST PROBLEM SIZE OR NUMBER OF PROCESSORS\n     SO THAT NX, NY AND NZ ARE LESS THAN OR EQUAL TO \n     ISIZ1, ISIZ2 AND ISIZ3 RESPECTIVELY.  THEY ARE\n     CURRENTLY%4d%4d%4d\n"
	.text
	.align	1
	.globl	domain
	.hidden	domain
	.type	domain, @function
domain:
.LFB11:
	.loc 1 107 19 is_stmt 1
	.cfi_startproc
	.loc 1 112 3
	.loc 1 112 6 is_stmt 0
	lla	a5,.LANCHOR0
	lw	a1,0(a5)
	.loc 1 113 6
	lw	a2,4(a5)
	.loc 1 114 6
	lw	a3,536(a5)
	.loc 1 107 19
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	ra,8(sp)
	.cfi_offset 1, -8
	.loc 1 112 6
	sw	a1,540(a5)
	.loc 1 113 3 is_stmt 1
	.loc 1 113 6 is_stmt 0
	sw	a2,544(a5)
	.loc 1 114 3 is_stmt 1
	.loc 1 114 6 is_stmt 0
	sw	a3,8(a5)
	.loc 1 119 3 is_stmt 1
	.loc 1 119 6 is_stmt 0
	li	a5,3
	ble	a1,a5,.L8
	.loc 1 119 14 discriminator 1
	ble	a2,a5,.L8
	.loc 1 119 24 discriminator 2
	ble	a3,a5,.L8
	.loc 1 128 3 is_stmt 1
	.loc 1 128 6 is_stmt 0
	li	a5,12
	bgt	a1,a5,.L10
	.loc 1 128 18 discriminator 1
	bgt	a2,a5,.L10
	.loc 1 128 32 discriminator 2
	bgt	a3,a5,.L10
	.loc 1 146 1
	ld	ra,8(sp)
	.cfi_remember_state
	.cfi_restore 1
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
.L8:
	.cfi_restore_state
	.loc 1 120 5 is_stmt 1
	lla	a0,.LC1
	call	printf@plt
.LVL7:
	.loc 1 125 5
	li	a0,1
	call	exit@plt
.LVL8:
.L10:
	.loc 1 129 5
	lla	a0,.LC2
	call	printf@plt
.LVL9:
	.loc 1 135 5
	li	a0,1
	call	exit@plt
.LVL10:
	.cfi_endproc
.LFE11:
	.size	domain, .-domain
	.align	1
	.globl	setcoeff
	.hidden	setcoeff
	.type	setcoeff, @function
setcoeff:
.LFB12:
	.loc 1 148 21
	.cfi_startproc
	.loc 1 152 3
	.loc 1 153 3
	.loc 1 154 3
	.loc 1 156 3
	.loc 1 157 3
	.loc 1 158 3
	.loc 1 160 3
	.loc 1 161 3
	.loc 1 162 3
	.loc 1 164 3
	.loc 1 165 3
	.loc 1 166 3
	.loc 1 168 3
	.loc 1 169 3
	.loc 1 170 3
	.loc 1 171 3
	.loc 1 172 3
	.loc 1 173 3
	.loc 1 178 3
	.loc 1 179 3
	.loc 1 180 3
	.loc 1 181 3
	.loc 1 182 3
	.loc 1 184 3
	.loc 1 185 3
	.loc 1 186 3
	.loc 1 187 3
	.loc 1 188 3
	.loc 1 190 3
	.loc 1 191 3
	.loc 1 192 3
	.loc 1 193 3
	.loc 1 194 3
	.loc 1 199 3
	.loc 1 204 3
	.loc 1 204 12 is_stmt 0
	lla	a5,.LANCHOR0
	fld	fa5,.LC3,a4
	.loc 1 216 13
	fld	fa4,.LC12,a4
	.loc 1 209 12
	fld	fa2,.LC6,a4
	.loc 1 210 12
	fld	fa0,.LC7,a4
	.loc 1 213 12
	fld	fa3,.LC10,a4
	.loc 1 215 13
	fld	fa1,.LC11,a4
	.loc 1 212 12
	fld	ft0,.LC9,a4
	.loc 1 221 12
	fld	ft1,.LC13,a4
	.loc 1 207 12
	fld	ft4,.LC4,a4
	.loc 1 208 12
	fld	ft5,.LC5,a4
	.loc 1 211 12
	fld	ft6,.LC8,a4
	.loc 1 212 12
	fsd	ft0,80(a5)
	.loc 1 221 12
	fsd	ft1,120(a5)
	.loc 1 225 12
	fsd	ft1,152(a5)
	.loc 1 228 12
	fsd	ft0,176(a5)
	.loc 1 204 12
	fsd	fa5,16(a5)
	.loc 1 205 3 is_stmt 1
	.loc 1 205 12 is_stmt 0
	sd	zero,24(a5)
	.loc 1 206 3 is_stmt 1
	.loc 1 206 12 is_stmt 0
	sd	zero,32(a5)
	.loc 1 207 3 is_stmt 1
	.loc 1 207 12 is_stmt 0
	fsd	ft4,40(a5)
	.loc 1 208 3 is_stmt 1
	.loc 1 208 12 is_stmt 0
	fsd	ft5,48(a5)
	.loc 1 209 3 is_stmt 1
	.loc 1 209 12 is_stmt 0
	fsd	fa2,56(a5)
	.loc 1 210 3 is_stmt 1
	.loc 1 210 12 is_stmt 0
	fsd	fa0,64(a5)
	.loc 1 211 3 is_stmt 1
	.loc 1 211 12 is_stmt 0
	fsd	ft6,72(a5)
	.loc 1 212 3 is_stmt 1
	.loc 1 213 3
	.loc 1 213 12 is_stmt 0
	fsd	fa3,88(a5)
	.loc 1 214 3 is_stmt 1
	.loc 1 214 13 is_stmt 0
	fsd	fa0,96(a5)
	.loc 1 215 3 is_stmt 1
	.loc 1 215 13 is_stmt 0
	fsd	fa1,104(a5)
	.loc 1 216 3 is_stmt 1
	.loc 1 216 13 is_stmt 0
	fsd	fa4,112(a5)
	.loc 1 221 3 is_stmt 1
	.loc 1 222 3
	.loc 1 222 12 is_stmt 0
	sd	zero,128(a5)
	.loc 1 223 3 is_stmt 1
	.loc 1 223 12 is_stmt 0
	sd	zero,136(a5)
	.loc 1 224 3 is_stmt 1
	.loc 1 224 12 is_stmt 0
	sd	zero,144(a5)
	.loc 1 225 3 is_stmt 1
	.loc 1 226 3
	.loc 1 226 12 is_stmt 0
	fsd	fa5,160(a5)
	.loc 1 227 3 is_stmt 1
	.loc 1 227 12 is_stmt 0
	fsd	fa2,168(a5)
	.loc 1 228 3 is_stmt 1
	.loc 1 229 3
	.loc 1 229 12 is_stmt 0
	fsd	fa3,184(a5)
	.loc 1 230 3 is_stmt 1
	.loc 1 245 12 is_stmt 0
	fld	ft1,.LC14,a4
	.loc 1 247 12
	fld	ft2,.LC15,a4
	.loc 1 265 13
	fld	ft3,.LC16,a4
	.loc 1 266 13
	fld	ft0,.LC17,a4
	.loc 1 230 12
	fsd	ft6,192(a5)
	.loc 1 231 3 is_stmt 1
	.loc 1 231 13 is_stmt 0
	fsd	fa1,200(a5)
	.loc 1 232 3 is_stmt 1
	.loc 1 232 13 is_stmt 0
	fsd	fa4,208(a5)
	.loc 1 233 3 is_stmt 1
	.loc 1 233 13 is_stmt 0
	fsd	fa0,216(a5)
	.loc 1 238 3 is_stmt 1
	.loc 1 238 12 is_stmt 0
	fsd	fa5,224(a5)
	.loc 1 239 3 is_stmt 1
	.loc 1 239 12 is_stmt 0
	fsd	fa5,232(a5)
	.loc 1 240 3 is_stmt 1
	.loc 1 240 12 is_stmt 0
	sd	zero,240(a5)
	.loc 1 241 3 is_stmt 1
	.loc 1 241 12 is_stmt 0
	sd	zero,248(a5)
	.loc 1 242 3 is_stmt 1
	.loc 1 242 12 is_stmt 0
	sd	zero,256(a5)
	.loc 1 243 3 is_stmt 1
	.loc 1 243 12 is_stmt 0
	fsd	fa5,264(a5)
	.loc 1 244 3 is_stmt 1
	.loc 1 244 12 is_stmt 0
	fsd	fa2,272(a5)
	.loc 1 245 3 is_stmt 1
	.loc 1 245 12 is_stmt 0
	fsd	ft1,280(a5)
	.loc 1 246 3 is_stmt 1
	.loc 1 246 12 is_stmt 0
	fsd	fa3,288(a5)
	.loc 1 247 3 is_stmt 1
	.loc 1 247 12 is_stmt 0
	fsd	ft2,296(a5)
	.loc 1 248 3 is_stmt 1
	.loc 1 248 13 is_stmt 0
	fsd	fa4,304(a5)
	.loc 1 249 3 is_stmt 1
	.loc 1 249 13 is_stmt 0
	fsd	fa0,312(a5)
	.loc 1 250 3 is_stmt 1
	.loc 1 250 13 is_stmt 0
	fsd	fa1,320(a5)
	.loc 1 255 3 is_stmt 1
	.loc 1 255 12 is_stmt 0
	fsd	fa5,328(a5)
	.loc 1 256 3 is_stmt 1
	.loc 1 256 12 is_stmt 0
	fsd	fa5,336(a5)
	.loc 1 257 3 is_stmt 1
	.loc 1 257 12 is_stmt 0
	sd	zero,344(a5)
	.loc 1 258 3 is_stmt 1
	.loc 1 258 12 is_stmt 0
	sd	zero,352(a5)
	.loc 1 259 3 is_stmt 1
	.loc 1 259 12 is_stmt 0
	sd	zero,360(a5)
	.loc 1 260 3 is_stmt 1
	.loc 1 260 12 is_stmt 0
	fsd	fa5,368(a5)
	.loc 1 261 3 is_stmt 1
	.loc 1 261 12 is_stmt 0
	fsd	fa2,376(a5)
	.loc 1 262 3 is_stmt 1
	.loc 1 262 12 is_stmt 0
	fsd	fa3,384(a5)
	.loc 1 263 3 is_stmt 1
	.loc 1 263 12 is_stmt 0
	fsd	ft2,392(a5)
	.loc 1 264 3 is_stmt 1
	.loc 1 264 12 is_stmt 0
	fsd	ft1,400(a5)
	.loc 1 265 3 is_stmt 1
	.loc 1 265 13 is_stmt 0
	fsd	ft3,408(a5)
	.loc 1 266 3 is_stmt 1
	.loc 1 266 13 is_stmt 0
	fsd	ft0,416(a5)
	.loc 1 267 3 is_stmt 1
	.loc 1 267 13 is_stmt 0
	fsd	fa4,424(a5)
	.loc 1 272 3 is_stmt 1
	.loc 1 272 12 is_stmt 0
	fsd	ft5,432(a5)
	.loc 1 273 3 is_stmt 1
	.loc 1 273 12 is_stmt 0
	fsd	ft4,440(a5)
	.loc 1 274 3 is_stmt 1
	.loc 1 274 12 is_stmt 0
	fsd	fa2,448(a5)
	.loc 1 275 3 is_stmt 1
	.loc 1 275 12 is_stmt 0
	fsd	fa5,456(a5)
	.loc 1 276 3 is_stmt 1
	.loc 1 276 12 is_stmt 0
	fsd	ft0,464(a5)
	.loc 1 277 3 is_stmt 1
	.loc 1 277 12 is_stmt 0
	fsd	fa1,472(a5)
	.loc 1 278 3 is_stmt 1
	.loc 1 278 12 is_stmt 0
	fsd	fa4,480(a5)
	.loc 1 279 3 is_stmt 1
	.loc 1 279 12 is_stmt 0
	fsd	ft2,488(a5)
	.loc 1 280 3 is_stmt 1
	.loc 1 280 12 is_stmt 0
	fsd	ft1,496(a5)
	.loc 1 281 3 is_stmt 1
	.loc 1 281 12 is_stmt 0
	fsd	fa3,504(a5)
	.loc 1 282 3 is_stmt 1
	.loc 1 282 13 is_stmt 0
	fsd	ft0,512(a5)
	.loc 1 283 3 is_stmt 1
	.loc 1 283 13 is_stmt 0
	fsd	fa4,520(a5)
	.loc 1 284 3 is_stmt 1
	.loc 1 284 13 is_stmt 0
	fsd	ft3,528(a5)
	.loc 1 285 1
	ret
	.cfi_endproc
.LFE12:
	.size	setcoeff, .-setcoeff
	.section	.rodata.str1.8
	.align	3
.LC18:
	.string	"[%d] starting setbv\n"
	.text
	.align	1
	.globl	setbv
	.hidden	setbv
	.type	setbv, @function
setbv:
.LFB13:
	.loc 1 287 18 is_stmt 1
	.cfi_startproc
	.loc 1 295 3
	.loc 1 296 3
	.loc 1 303 3
.LBB4:
.LBB5:
	.file 2 "../common/util.h"
	.loc 2 19 3
	.loc 2 20 3
.LBE5:
.LBE4:
	.loc 1 287 18 is_stmt 0
	addi	sp,sp,-96
	.cfi_def_cfa_offset 96
	sd	ra,88(sp)
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
.LBB8:
.LBB6:
	.loc 2 20 3
#APP
# 20 "../common/util.h" 1
	csrr    a0, mhartid
# 0 "" 2
	.loc 2 21 3 is_stmt 1
#NO_APP
.LBE6:
.LBE8:
	.loc 1 307 17 is_stmt 0
	lla	s9,.LANCHOR0
.LBB9:
.LBB7:
	.loc 2 21 10
	mv	a1,a0
.LBE7:
.LBE9:
	.loc 1 303 3
	lla	a0,.LC18
	call	printf@plt
.LVL11:
	.loc 1 307 3 is_stmt 1
	.loc 1 307 17
	lw	s8,540(s9)
	ble	s8,zero,.L14
	.loc 1 309 19 is_stmt 0
	lw	s5,544(s9)
	.loc 1 307 17
	li	s7,8192
	lla	s6,u
	.loc 1 307 10
	li	s2,0
	.loc 1 307 17
	addi	s7,s7,-1432
.LVL12:
.L16:
	.loc 1 309 19 is_stmt 1
	ble	s5,zero,.L19
	.loc 1 312 7 is_stmt 0
	lw	s4,8(s9)
	mv	s1,s6
	.loc 1 309 12
	li	s0,0
	.loc 1 312 7
	addiw	s4,s4,-1
	slli	s3,s4,2
	add	s3,s3,s4
	slli	s3,s3,3
.LVL13:
.L17:
	.loc 1 310 7 is_stmt 1 discriminator 3
	.loc 1 311 7 discriminator 3
	mv	a3,s1
	mv	a1,s0
	li	a2,0
	mv	a0,s2
	call	exact
.LVL14:
	.loc 1 312 7 discriminator 3
	add	a3,s1,s3
	mv	a1,s0
	mv	a2,s4
	mv	a0,s2
	.loc 1 309 26 is_stmt 0 discriminator 3
	addiw	s0,s0,1
.LVL15:
	.loc 1 312 7 discriminator 3
	call	exact
.LVL16:
	.loc 1 309 26 is_stmt 1 discriminator 3
	.loc 1 309 19 discriminator 3
	addi	s1,s1,520
	bne	s0,s5,.L17
.L19:
	.loc 1 307 24
	addiw	s2,s2,1
.LVL17:
	.loc 1 307 17
	add	s6,s6,s7
	bne	s2,s8,.L16
.L14:
	.loc 1 320 1 is_stmt 0
	ld	ra,88(sp)
	.cfi_restore 1
	ld	s0,80(sp)
	.cfi_restore 8
	ld	s1,72(sp)
	.cfi_restore 9
	ld	s2,64(sp)
	.cfi_restore 18
	ld	s3,56(sp)
	.cfi_restore 19
	ld	s4,48(sp)
	.cfi_restore 20
	ld	s5,40(sp)
	.cfi_restore 21
	ld	s6,32(sp)
	.cfi_restore 22
	ld	s7,24(sp)
	.cfi_restore 23
	ld	s8,16(sp)
	.cfi_restore 24
	ld	s9,8(sp)
	.cfi_restore 25
	addi	sp,sp,96
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE13:
	.size	setbv, .-setbv
	.hidden	core0_expected
	.globl	core0_expected
	.hidden	core0_results
	.globl	core0_results
	.hidden	errors
	.globl	errors
	.hidden	core1_completed
	.globl	core1_completed
	.hidden	core0_completed
	.globl	core0_completed
	.section	.rodata.cst8,"aM",@progbits,8
	.align	3
.LC3:
	.word	0
	.word	1073741824
	.align	3
.LC4:
	.word	0
	.word	1074790400
	.align	3
.LC5:
	.word	0
	.word	1075052544
	.align	3
.LC6:
	.word	0
	.word	1074266112
	.align	3
.LC7:
	.word	0
	.word	1071644672
	.align	3
.LC8:
	.word	1202590843
	.word	1066695393
	.align	3
.LC9:
	.word	1202590843
	.word	1065646817
	.align	3
.LC10:
	.word	-343597384
	.word	1067366481
	.align	3
.LC11:
	.word	-1717986918
	.word	1071225241
	.align	3
.LC12:
	.word	858993459
	.word	1070805811
	.align	3
.LC13:
	.word	0
	.word	1072693248
	.align	3
.LC14:
	.word	1202590843
	.word	1067743969
	.align	3
.LC15:
	.word	-1717986918
	.word	1068079513
	.align	3
.LC16:
	.word	-1717986918
	.word	1070176665
	.align	3
.LC17:
	.word	-1717986918
	.word	1069128089
	.bss
	.align	3
	.set	.LANCHOR0,. + 0
	.type	nx0, @object
	.size	nx0, 4
nx0:
	.zero	4
	.type	ny0, @object
	.size	ny0, 4
ny0:
	.zero	4
	.type	nz, @object
	.size	nz, 4
nz:
	.zero	4
	.zero	4
	.type	ce, @object
	.size	ce, 520
ce:
	.zero	520
	.type	nz0, @object
	.size	nz0, 4
nz0:
	.zero	4
	.type	nx, @object
	.size	nx, 4
nx:
	.zero	4
	.type	ny, @object
	.size	ny, 4
ny:
	.zero	4
	.zero	4
	.type	core0_expected, @object
	.size	core0_expected, 1600
core0_expected:
	.zero	1600
	.type	core0_results, @object
	.size	core0_results, 1600
core0_results:
	.zero	1600
	.type	errors, @object
	.size	errors, 4
errors:
	.zero	4
	.type	core1_completed, @object
	.size	core1_completed, 4
core1_completed:
	.zero	4
	.type	core0_completed, @object
	.size	core0_completed, 4
core0_completed:
	.zero	4
	.zero	4
	.type	u, @object
	.size	u, 81120
u:
	.zero	81120
	.text
.Letext0:
	.file 3 "applu.h"
	.file 4 "<built-in>"
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.4byte	0x758
	.2byte	0x5
	.byte	0x1
	.byte	0x8
	.4byte	.Ldebug_abbrev0
	.byte	0x11
	.4byte	.LASF41
	.byte	0x1d
	.4byte	.LASF0
	.4byte	.LASF1
	.8byte	.Ltext0
	.8byte	.Letext0-.Ltext0
	.4byte	.Ldebug_line0
	.byte	0x6
	.byte	0x8
	.byte	0x7
	.4byte	.LASF2
	.byte	0x6
	.byte	0x1
	.byte	0x8
	.4byte	.LASF3
	.byte	0x6
	.byte	0x2
	.byte	0x7
	.4byte	.LASF4
	.byte	0x6
	.byte	0x4
	.byte	0x7
	.4byte	.LASF5
	.byte	0x6
	.byte	0x1
	.byte	0x6
	.4byte	.LASF6
	.byte	0x6
	.byte	0x2
	.byte	0x5
	.4byte	.LASF7
	.byte	0x12
	.byte	0x4
	.byte	0x5
	.string	"int"
	.byte	0xa
	.4byte	0x58
	.byte	0x6
	.byte	0x8
	.byte	0x5
	.4byte	.LASF8
	.byte	0x6
	.byte	0x1
	.byte	0x8
	.4byte	.LASF9
	.byte	0x13
	.4byte	0x6b
	.byte	0x5
	.string	"nx"
	.byte	0x3
	.byte	0x2a
	.byte	0xc
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	nx
	.byte	0x5
	.string	"ny"
	.byte	0x3
	.byte	0x2a
	.byte	0x10
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	ny
	.byte	0x5
	.string	"nz"
	.byte	0x3
	.byte	0x2a
	.byte	0x14
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	nz
	.byte	0x5
	.string	"nx0"
	.byte	0x3
	.byte	0x2b
	.byte	0xc
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	nx0
	.byte	0x5
	.string	"ny0"
	.byte	0x3
	.byte	0x2b
	.byte	0x11
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	ny0
	.byte	0x5
	.string	"nz0"
	.byte	0x3
	.byte	0x2b
	.byte	0x16
	.4byte	0x58
	.byte	0x9
	.byte	0x3
	.8byte	nz0
	.byte	0x1
	.string	"ist"
	.byte	0x3
	.byte	0x2c
	.byte	0xc
	.4byte	0x58
	.byte	0x2
	.4byte	.LASF10
	.byte	0x2c
	.byte	0x11
	.4byte	0x58
	.byte	0x1
	.string	"jst"
	.byte	0x3
	.byte	0x2d
	.byte	0xc
	.4byte	0x58
	.byte	0x2
	.4byte	.LASF11
	.byte	0x2d
	.byte	0x11
	.4byte	0x58
	.byte	0x1
	.string	"ii1"
	.byte	0x3
	.byte	0x2e
	.byte	0xc
	.4byte	0x58
	.byte	0x1
	.string	"ii2"
	.byte	0x3
	.byte	0x2e
	.byte	0x11
	.4byte	0x58
	.byte	0x1
	.string	"ji1"
	.byte	0x3
	.byte	0x2f
	.byte	0xc
	.4byte	0x58
	.byte	0x1
	.string	"ji2"
	.byte	0x3
	.byte	0x2f
	.byte	0x11
	.4byte	0x58
	.byte	0x1
	.string	"ki1"
	.byte	0x3
	.byte	0x30
	.byte	0xc
	.4byte	0x58
	.byte	0x1
	.string	"ki2"
	.byte	0x3
	.byte	0x30
	.byte	0x11
	.4byte	0x58
	.byte	0x1
	.string	"dxi"
	.byte	0x3
	.byte	0x31
	.byte	0xf
	.4byte	0x17a
	.byte	0x6
	.byte	0x8
	.byte	0x4
	.4byte	.LASF12
	.byte	0xa
	.4byte	0x17a
	.byte	0x2
	.4byte	.LASF13
	.byte	0x31
	.byte	0x14
	.4byte	0x17a
	.byte	0x2
	.4byte	.LASF14
	.byte	0x31
	.byte	0x1a
	.4byte	0x17a
	.byte	0x1
	.string	"tx1"
	.byte	0x3
	.byte	0x32
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"tx2"
	.byte	0x3
	.byte	0x32
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"tx3"
	.byte	0x3
	.byte	0x32
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"ty1"
	.byte	0x3
	.byte	0x33
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"ty2"
	.byte	0x3
	.byte	0x33
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"ty3"
	.byte	0x3
	.byte	0x33
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"tz1"
	.byte	0x3
	.byte	0x34
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"tz2"
	.byte	0x3
	.byte	0x34
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"tz3"
	.byte	0x3
	.byte	0x34
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"dx1"
	.byte	0x3
	.byte	0x3b
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"dx2"
	.byte	0x3
	.byte	0x3b
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"dx3"
	.byte	0x3
	.byte	0x3b
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"dx4"
	.byte	0x3
	.byte	0x3b
	.byte	0x1e
	.4byte	0x17a
	.byte	0x1
	.string	"dx5"
	.byte	0x3
	.byte	0x3b
	.byte	0x23
	.4byte	0x17a
	.byte	0x1
	.string	"dy1"
	.byte	0x3
	.byte	0x3c
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"dy2"
	.byte	0x3
	.byte	0x3c
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"dy3"
	.byte	0x3
	.byte	0x3c
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"dy4"
	.byte	0x3
	.byte	0x3c
	.byte	0x1e
	.4byte	0x17a
	.byte	0x1
	.string	"dy5"
	.byte	0x3
	.byte	0x3c
	.byte	0x23
	.4byte	0x17a
	.byte	0x1
	.string	"dz1"
	.byte	0x3
	.byte	0x3d
	.byte	0xf
	.4byte	0x17a
	.byte	0x1
	.string	"dz2"
	.byte	0x3
	.byte	0x3d
	.byte	0x14
	.4byte	0x17a
	.byte	0x1
	.string	"dz3"
	.byte	0x3
	.byte	0x3d
	.byte	0x19
	.4byte	0x17a
	.byte	0x1
	.string	"dz4"
	.byte	0x3
	.byte	0x3d
	.byte	0x1e
	.4byte	0x17a
	.byte	0x1
	.string	"dz5"
	.byte	0x3
	.byte	0x3d
	.byte	0x23
	.4byte	0x17a
	.byte	0x2
	.4byte	.LASF15
	.byte	0x3e
	.byte	0xf
	.4byte	0x17a
	.byte	0x7
	.4byte	0x17a
	.4byte	0x2e9
	.byte	0x3
	.4byte	0x2e
	.byte	0xb
	.byte	0x3
	.4byte	0x2e
	.byte	0xc
	.byte	0x3
	.4byte	0x2e
	.byte	0xc
	.byte	0x3
	.4byte	0x2e
	.byte	0x4
	.byte	0
	.byte	0x5
	.string	"u"
	.byte	0x3
	.byte	0x49
	.byte	0xf
	.4byte	0x2c7
	.byte	0x9
	.byte	0x3
	.8byte	u
	.byte	0x1
	.string	"rsd"
	.byte	0x3
	.byte	0x4a
	.byte	0xf
	.4byte	0x2c7
	.byte	0x2
	.4byte	.LASF16
	.byte	0x4b
	.byte	0xf
	.4byte	0x2c7
	.byte	0x2
	.4byte	.LASF17
	.byte	0x4c
	.byte	0xf
	.4byte	0x2c7
	.byte	0x1
	.string	"ipr"
	.byte	0x3
	.byte	0x53
	.byte	0xc
	.4byte	0x58
	.byte	0x2
	.4byte	.LASF18
	.byte	0x53
	.byte	0x11
	.4byte	0x58
	.byte	0x2
	.4byte	.LASF19
	.byte	0x5a
	.byte	0xc
	.4byte	0x58
	.byte	0x2
	.4byte	.LASF20
	.byte	0x5a
	.byte	0x13
	.4byte	0x58
	.byte	0x1
	.string	"dt"
	.byte	0x3
	.byte	0x5b
	.byte	0xf
	.4byte	0x17a
	.byte	0x2
	.4byte	.LASF21
	.byte	0x5b
	.byte	0x13
	.4byte	0x17a
	.byte	0x7
	.4byte	0x17a
	.4byte	0x372
	.byte	0x3
	.4byte	0x2e
	.byte	0x4
	.byte	0
	.byte	0x2
	.4byte	.LASF22
	.byte	0x5b
	.byte	0x1a
	.4byte	0x362
	.byte	0x2
	.4byte	.LASF23
	.byte	0x5b
	.byte	0x25
	.4byte	0x362
	.byte	0x2
	.4byte	.LASF24
	.byte	0x5b
	.byte	0x2f
	.4byte	0x362
	.byte	0x1
	.string	"frc"
	.byte	0x3
	.byte	0x5b
	.byte	0x39
	.4byte	0x17a
	.byte	0x2
	.4byte	.LASF25
	.byte	0x5b
	.byte	0x3e
	.4byte	0x17a
	.byte	0x7
	.4byte	0x17a
	.4byte	0x3cc
	.byte	0x3
	.4byte	0x2e
	.byte	0xb
	.byte	0x3
	.4byte	0x2e
	.byte	0xb
	.byte	0x3
	.4byte	0x2e
	.byte	0x4
	.byte	0x3
	.4byte	0x2e
	.byte	0x4
	.byte	0
	.byte	0x1
	.string	"a"
	.byte	0x3
	.byte	0x5e
	.byte	0xf
	.4byte	0x3aa
	.byte	0x1
	.string	"b"
	.byte	0x3
	.byte	0x5f
	.byte	0xf
	.4byte	0x3aa
	.byte	0x1
	.string	"c"
	.byte	0x3
	.byte	0x60
	.byte	0xf
	.4byte	0x3aa
	.byte	0x1
	.string	"d"
	.byte	0x3
	.byte	0x61
	.byte	0xf
	.4byte	0x3aa
	.byte	0x7
	.4byte	0x17a
	.4byte	0x40a
	.byte	0x3
	.4byte	0x2e
	.byte	0x4
	.byte	0x3
	.4byte	0x2e
	.byte	0xc
	.byte	0
	.byte	0x5
	.string	"ce"
	.byte	0x3
	.byte	0x68
	.byte	0xf
	.4byte	0x3f4
	.byte	0x9
	.byte	0x3
	.8byte	ce
	.byte	0x2
	.4byte	.LASF26
	.byte	0x6f
	.byte	0xf
	.4byte	0x17a
	.byte	0x8
	.4byte	.LASF27
	.byte	0x1e
	.byte	0xe
	.4byte	0x5f
	.byte	0x9
	.byte	0x3
	.8byte	core0_completed
	.byte	0x8
	.4byte	.LASF28
	.byte	0x1f
	.byte	0xe
	.4byte	0x5f
	.byte	0x9
	.byte	0x3
	.8byte	core1_completed
	.byte	0x8
	.4byte	.LASF29
	.byte	0x20
	.byte	0xe
	.4byte	0x5f
	.byte	0x9
	.byte	0x3
	.8byte	errors
	.byte	0x7
	.4byte	0x181
	.4byte	0x47f
	.byte	0x3
	.4byte	0x2e
	.byte	0x18
	.byte	0x3
	.4byte	0x2e
	.byte	0x7
	.byte	0
	.byte	0xa
	.4byte	0x469
	.byte	0x8
	.4byte	.LASF30
	.byte	0x27
	.byte	0x11
	.4byte	0x47f
	.byte	0x9
	.byte	0x3
	.8byte	core0_results
	.byte	0x8
	.4byte	.LASF31
	.byte	0x28
	.byte	0x11
	.4byte	0x47f
	.byte	0x9
	.byte	0x3
	.8byte	core0_expected
	.byte	0x14
	.4byte	.LASF32
	.byte	0x2
	.byte	0x8
	.byte	0x27
	.4byte	0x4c0
	.byte	0xd
	.4byte	0x58
	.byte	0
	.byte	0x15
	.4byte	.LASF33
	.byte	0x2
	.byte	0x5
	.byte	0x5
	.4byte	0x58
	.4byte	0x4d7
	.byte	0xd
	.4byte	0x4d7
	.byte	0x16
	.byte	0
	.byte	0xe
	.4byte	0x72
	.byte	0x17
	.4byte	.LASF36
	.byte	0x1
	.2byte	0x11f
	.byte	0x6
	.8byte	.LFB13
	.8byte	.LFE13-.LFB13
	.byte	0x1
	.byte	0x9c
	.4byte	0x5cf
	.byte	0xf
	.string	"i"
	.byte	0x7
	.4byte	0x58
	.4byte	.LLST2
	.byte	0xf
	.string	"j"
	.byte	0xa
	.4byte	0x58
	.4byte	.LLST3
	.byte	0x18
	.string	"k"
	.byte	0x1
	.2byte	0x127
	.byte	0xd
	.4byte	0x58
	.byte	0x19
	.4byte	.LASF34
	.byte	0x1
	.2byte	0x128
	.byte	0x7
	.4byte	0x58
	.byte	0x1a
	.4byte	.LASF35
	.byte	0x1
	.2byte	0x128
	.byte	0xe
	.4byte	0x58
	.4byte	.LLST4
	.byte	0x1b
	.4byte	0x732
	.8byte	.LBB4
	.4byte	.LLRL5
	.byte	0x1
	.2byte	0x12f
	.byte	0x3
	.4byte	0x563
	.byte	0x1c
	.4byte	.LLRL5
	.byte	0x1d
	.4byte	0x743
	.byte	0x1
	.byte	0x5a
	.byte	0
	.byte	0
	.byte	0x9
	.8byte	.LVL11
	.4byte	0x4c0
	.4byte	0x582
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x9
	.byte	0x3
	.8byte	.LC18
	.byte	0
	.byte	0x9
	.8byte	.LVL14
	.4byte	0x6a6
	.4byte	0x5ab
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x2
	.byte	0x82
	.byte	0
	.byte	0x4
	.byte	0x1
	.byte	0x5b
	.byte	0x2
	.byte	0x78
	.byte	0
	.byte	0x4
	.byte	0x1
	.byte	0x5c
	.byte	0x1
	.byte	0x30
	.byte	0x4
	.byte	0x1
	.byte	0x5d
	.byte	0x2
	.byte	0x79
	.byte	0
	.byte	0
	.byte	0xb
	.8byte	.LVL16
	.4byte	0x6a6
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x2
	.byte	0x82
	.byte	0
	.byte	0x4
	.byte	0x1
	.byte	0x5c
	.byte	0x2
	.byte	0x84
	.byte	0
	.byte	0x4
	.byte	0x1
	.byte	0x5d
	.byte	0x5
	.byte	0x79
	.byte	0
	.byte	0x83
	.byte	0
	.byte	0x22
	.byte	0
	.byte	0
	.byte	0x1e
	.4byte	.LASF42
	.byte	0x1
	.byte	0x94
	.byte	0x6
	.8byte	.LFB12
	.8byte	.LFE12-.LFB12
	.byte	0x1
	.byte	0x9c
	.byte	0x10
	.4byte	.LASF37
	.byte	0x6b
	.8byte	.LFB11
	.8byte	.LFE11-.LFB11
	.byte	0x1
	.byte	0x9c
	.4byte	0x66e
	.byte	0x9
	.8byte	.LVL7
	.4byte	0x4c0
	.4byte	0x624
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x9
	.byte	0x3
	.8byte	.LC1
	.byte	0
	.byte	0x9
	.8byte	.LVL8
	.4byte	0x4ae
	.4byte	0x63b
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x1
	.byte	0x31
	.byte	0
	.byte	0x9
	.8byte	.LVL9
	.4byte	0x4c0
	.4byte	0x65a
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x9
	.byte	0x3
	.8byte	.LC2
	.byte	0
	.byte	0xb
	.8byte	.LVL10
	.4byte	0x4ae
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x1
	.byte	0x31
	.byte	0
	.byte	0
	.byte	0x10
	.4byte	.LASF38
	.byte	0x4a
	.8byte	.LFB10
	.8byte	.LFE10-.LFB10
	.byte	0x1
	.byte	0x9c
	.4byte	0x6a6
	.byte	0xb
	.8byte	.LVL6
	.4byte	0x750
	.byte	0x4
	.byte	0x1
	.byte	0x5a
	.byte	0x9
	.byte	0x3
	.8byte	.LC0
	.byte	0
	.byte	0
	.byte	0x1f
	.4byte	.LASF43
	.byte	0x1
	.byte	0x2e
	.byte	0xd
	.8byte	.LFB9
	.8byte	.LFE9-.LFB9
	.byte	0x1
	.byte	0x9c
	.4byte	0x72d
	.byte	0xc
	.string	"i"
	.byte	0x17
	.4byte	0x58
	.byte	0x1
	.byte	0x5a
	.byte	0xc
	.string	"j"
	.byte	0x1e
	.4byte	0x58
	.byte	0x1
	.byte	0x5b
	.byte	0xc
	.string	"k"
	.byte	0x25
	.4byte	0x58
	.byte	0x1
	.byte	0x5c
	.byte	0x20
	.4byte	.LASF39
	.byte	0x1
	.byte	0x2e
	.byte	0x2f
	.4byte	0x72d
	.4byte	.LLST0
	.byte	0x21
	.string	"m"
	.byte	0x1
	.byte	0x38
	.byte	0x7
	.4byte	0x58
	.4byte	.LLST1
	.byte	0x5
	.string	"xi"
	.byte	0x1
	.byte	0x39
	.byte	0xa
	.4byte	0x17a
	.byte	0x2
	.byte	0x90
	.byte	0x2d
	.byte	0x5
	.string	"eta"
	.byte	0x1
	.byte	0x39
	.byte	0xe
	.4byte	0x17a
	.byte	0x2
	.byte	0x90
	.byte	0x2e
	.byte	0x22
	.4byte	.LASF40
	.byte	0x1
	.byte	0x39
	.byte	0x13
	.4byte	0x17a
	.byte	0x2
	.byte	0x90
	.byte	0x2f
	.byte	0
	.byte	0xe
	.4byte	0x17a
	.byte	0x23
	.4byte	.LASF44
	.byte	0x2
	.byte	0x12
	.byte	0x16
	.4byte	0x2e
	.byte	0x1
	.4byte	0x750
	.byte	0x1
	.string	"ret"
	.byte	0x2
	.byte	0x13
	.byte	0x1a
	.4byte	0x2e
	.byte	0
	.byte	0x24
	.4byte	.LASF45
	.4byte	.LASF46
	.byte	0x4
	.byte	0
	.byte	0
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.byte	0x1
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x2
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0x21
	.byte	0x3
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x3
	.byte	0x21
	.byte	0
	.byte	0x49
	.byte	0x13
	.byte	0x2f
	.byte	0xb
	.byte	0
	.byte	0
	.byte	0x4
	.byte	0x49
	.byte	0
	.byte	0x2
	.byte	0x18
	.byte	0x7e
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0x5
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0x6
	.byte	0x24
	.byte	0
	.byte	0xb
	.byte	0xb
	.byte	0x3e
	.byte	0xb
	.byte	0x3
	.byte	0xe
	.byte	0
	.byte	0
	.byte	0x7
	.byte	0x1
	.byte	0x1
	.byte	0x49
	.byte	0x13
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x8
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0x21
	.byte	0x1
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x3f
	.byte	0x19
	.byte	0x2
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0x9
	.byte	0x48
	.byte	0x1
	.byte	0x7d
	.byte	0x1
	.byte	0x7f
	.byte	0x13
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0xa
	.byte	0x35
	.byte	0
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0xb
	.byte	0x48
	.byte	0x1
	.byte	0x7d
	.byte	0x1
	.byte	0x7f
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0xc
	.byte	0x5
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0x21
	.byte	0x1
	.byte	0x3b
	.byte	0x21
	.byte	0x2e
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0xd
	.byte	0x5
	.byte	0
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0xe
	.byte	0xf
	.byte	0
	.byte	0xb
	.byte	0x21
	.byte	0x8
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0xf
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0x21
	.byte	0x1
	.byte	0x3b
	.byte	0x21
	.byte	0xa7,0x2
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x10
	.byte	0x2e
	.byte	0x1
	.byte	0x3f
	.byte	0x19
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0x21
	.byte	0x1
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0x21
	.byte	0x6
	.byte	0x27
	.byte	0x19
	.byte	0x11
	.byte	0x1
	.byte	0x12
	.byte	0x7
	.byte	0x40
	.byte	0x18
	.byte	0x7a
	.byte	0x19
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x11
	.byte	0x11
	.byte	0x1
	.byte	0x25
	.byte	0xe
	.byte	0x13
	.byte	0xb
	.byte	0x3
	.byte	0x1f
	.byte	0x1b
	.byte	0x1f
	.byte	0x11
	.byte	0x1
	.byte	0x12
	.byte	0x7
	.byte	0x10
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x12
	.byte	0x24
	.byte	0
	.byte	0xb
	.byte	0xb
	.byte	0x3e
	.byte	0xb
	.byte	0x3
	.byte	0x8
	.byte	0
	.byte	0
	.byte	0x13
	.byte	0x26
	.byte	0
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x14
	.byte	0x2e
	.byte	0x1
	.byte	0x3f
	.byte	0x19
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x27
	.byte	0x19
	.byte	0x87,0x1
	.byte	0x19
	.byte	0x3c
	.byte	0x19
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x15
	.byte	0x2e
	.byte	0x1
	.byte	0x3f
	.byte	0x19
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x27
	.byte	0x19
	.byte	0x49
	.byte	0x13
	.byte	0x3c
	.byte	0x19
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x16
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0
	.byte	0x17
	.byte	0x2e
	.byte	0x1
	.byte	0x3f
	.byte	0x19
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0x5
	.byte	0x39
	.byte	0xb
	.byte	0x27
	.byte	0x19
	.byte	0x11
	.byte	0x1
	.byte	0x12
	.byte	0x7
	.byte	0x40
	.byte	0x18
	.byte	0x7a
	.byte	0x19
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x18
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0x5
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x19
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0x5
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x1a
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0x5
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x1b
	.byte	0x1d
	.byte	0x1
	.byte	0x31
	.byte	0x13
	.byte	0x52
	.byte	0x1
	.byte	0x55
	.byte	0x17
	.byte	0x58
	.byte	0xb
	.byte	0x59
	.byte	0x5
	.byte	0x57
	.byte	0xb
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x1c
	.byte	0xb
	.byte	0x1
	.byte	0x55
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x1d
	.byte	0x34
	.byte	0
	.byte	0x31
	.byte	0x13
	.byte	0x2
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0x1e
	.byte	0x2e
	.byte	0
	.byte	0x3f
	.byte	0x19
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x27
	.byte	0x19
	.byte	0x11
	.byte	0x1
	.byte	0x12
	.byte	0x7
	.byte	0x40
	.byte	0x18
	.byte	0x7a
	.byte	0x19
	.byte	0
	.byte	0
	.byte	0x1f
	.byte	0x2e
	.byte	0x1
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x27
	.byte	0x19
	.byte	0x11
	.byte	0x1
	.byte	0x12
	.byte	0x7
	.byte	0x40
	.byte	0x18
	.byte	0x7a
	.byte	0x19
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x20
	.byte	0x5
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x21
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0x8
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x17
	.byte	0
	.byte	0
	.byte	0x22
	.byte	0x34
	.byte	0
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x2
	.byte	0x18
	.byte	0
	.byte	0
	.byte	0x23
	.byte	0x2e
	.byte	0x1
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0x39
	.byte	0xb
	.byte	0x49
	.byte	0x13
	.byte	0x20
	.byte	0xb
	.byte	0x1
	.byte	0x13
	.byte	0
	.byte	0
	.byte	0x24
	.byte	0x2e
	.byte	0
	.byte	0x3f
	.byte	0x19
	.byte	0x3c
	.byte	0x19
	.byte	0x6e
	.byte	0xe
	.byte	0x3
	.byte	0xe
	.byte	0x3a
	.byte	0xb
	.byte	0x3b
	.byte	0xb
	.byte	0
	.byte	0
	.byte	0
	.section	.debug_loclists,"",@progbits
	.4byte	.Ldebug_loc3-.Ldebug_loc2
.Ldebug_loc2:
	.2byte	0x5
	.byte	0x8
	.byte	0
	.4byte	0
.Ldebug_loc0:
.LLST2:
	.byte	0x7
	.8byte	.LVL11
	.8byte	.LVL12
	.byte	0x2
	.byte	0x30
	.byte	0x9f
	.byte	0x7
	.8byte	.LVL12
	.8byte	.LVL17
	.byte	0x1
	.byte	0x62
	.byte	0
.LLST3:
	.byte	0x7
	.8byte	.LVL12
	.8byte	.LVL13
	.byte	0x2
	.byte	0x30
	.byte	0x9f
	.byte	0x7
	.8byte	.LVL13
	.8byte	.LVL15
	.byte	0x1
	.byte	0x58
	.byte	0
.LLST4:
	.byte	0x7
	.8byte	.LVL13
	.8byte	.LVL15
	.byte	0x1
	.byte	0x58
	.byte	0
.LLST0:
	.byte	0x7
	.8byte	.LVL0
	.8byte	.LVL3
	.byte	0x1
	.byte	0x5d
	.byte	0x7
	.8byte	.LVL3
	.8byte	.LFE9
	.byte	0x4
	.byte	0xa3
	.byte	0x1
	.byte	0x5d
	.byte	0x9f
	.byte	0
.LLST1:
	.byte	0x7
	.8byte	.LVL3
	.8byte	.LVL4
	.byte	0x16
	.byte	0x7f
	.byte	0
	.byte	0x3
	.8byte	ce
	.byte	0x1c
	.byte	0xa8
	.byte	0x2e
	.byte	0x8
	.byte	0x68
	.byte	0xa8
	.byte	0x2e
	.byte	0x1b
	.byte	0xa8
	.byte	0
	.byte	0x9f
	.byte	0x7
	.8byte	.LVL4
	.8byte	.LVL5
	.byte	0x16
	.byte	0x7f
	.byte	0
	.byte	0x3
	.8byte	ce+104
	.byte	0x1c
	.byte	0xa8
	.byte	0x2e
	.byte	0x8
	.byte	0x68
	.byte	0xa8
	.byte	0x2e
	.byte	0x1b
	.byte	0xa8
	.byte	0
	.byte	0x9f
	.byte	0
.Ldebug_loc3:
	.section	.debug_aranges,"",@progbits
	.4byte	0x2c
	.2byte	0x2
	.4byte	.Ldebug_info0
	.byte	0x8
	.byte	0
	.2byte	0
	.2byte	0
	.8byte	.Ltext0
	.8byte	.Letext0-.Ltext0
	.8byte	0
	.8byte	0
	.section	.debug_rnglists,"",@progbits
.Ldebug_ranges0:
	.4byte	.Ldebug_ranges3-.Ldebug_ranges2
.Ldebug_ranges2:
	.2byte	0x5
	.byte	0x8
	.byte	0
	.4byte	0
.LLRL5:
	.byte	0x6
	.8byte	.LBB4
	.8byte	.LBE4
	.byte	0x6
	.8byte	.LBB8
	.8byte	.LBE8
	.byte	0x6
	.8byte	.LBB9
	.8byte	.LBE9
	.byte	0
.Ldebug_ranges3:
	.section	.debug_line,"",@progbits
.Ldebug_line0:
	.section	.debug_str,"MS",@progbits,1
.LASF33:
	.string	"printf"
.LASF15:
	.string	"dssp"
.LASF35:
	.string	"jglob"
.LASF14:
	.string	"dzeta"
.LASF36:
	.string	"setbv"
.LASF17:
	.string	"flux"
.LASF30:
	.string	"core0_results"
.LASF26:
	.string	"maxtime"
.LASF6:
	.string	"signed char"
.LASF28:
	.string	"core1_completed"
.LASF8:
	.string	"long int"
.LASF11:
	.string	"jend"
.LASF44:
	.string	"get_hart_id"
.LASF12:
	.string	"double"
.LASF31:
	.string	"core0_expected"
.LASF5:
	.string	"unsigned int"
.LASF29:
	.string	"errors"
.LASF2:
	.string	"long unsigned int"
.LASF23:
	.string	"rsdnm"
.LASF34:
	.string	"iglob"
.LASF4:
	.string	"short unsigned int"
.LASF43:
	.string	"exact"
.LASF46:
	.string	"__builtin_puts"
.LASF45:
	.string	"puts"
.LASF24:
	.string	"errnm"
.LASF18:
	.string	"inorm"
.LASF40:
	.string	"zeta"
.LASF39:
	.string	"u000ijk"
.LASF42:
	.string	"setcoeff"
.LASF3:
	.string	"unsigned char"
.LASF13:
	.string	"deta"
.LASF7:
	.string	"short int"
.LASF21:
	.string	"omega"
.LASF32:
	.string	"exit"
.LASF22:
	.string	"tolrsd"
.LASF27:
	.string	"core0_completed"
.LASF38:
	.string	"read_input"
.LASF9:
	.string	"char"
.LASF10:
	.string	"iend"
.LASF25:
	.string	"ttotal"
.LASF41:
	.string	"GNU C17 11.4.0 -mcmodel=medany -mabi=lp64d -misa-spec=2.2 -march=rv64imafdc -g -O2 -fvisibility=hidden"
.LASF16:
	.string	"frct"
.LASF37:
	.string	"domain"
.LASF19:
	.string	"itmax"
.LASF20:
	.string	"invert"
	.section	.debug_line_str,"MS",@progbits,1
.LASF0:
	.string	"fpu_test.c"
.LASF1:
	.string	"/home/han4n/Documents/cva6/verif/tests/multicore/fpu_share"
	.ident	"GCC: (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0"
	.section	.note.GNU-stack,"",@progbits
