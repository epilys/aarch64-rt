/*
 * Copyright 2025 The aarch64-rt Authors.
 *
 * This project is dual-licensed under Apache 2.0 and MIT terms.
 * See LICENSE-APACHE and LICENSE-MIT for details.
 */

.macro adr_l, reg:req, sym:req
    adrp \reg, \sym
    add \reg, \reg, :lo12:\sym
.endm

/* 4kB pages */
.equ PAGE_SHIFT,            12

/* 1 if BE, 0 if LE */
.equ HEAD_FLAG_ENDIANNESS,  0
.equ HEAD_FLAG_PAGE_SIZE,   ((PAGE_SHIFT - 10) / 2)
.equ HEAD_FLAG_PHYS_BASE,   1
.equ HEAD_FLAGS,            ((HEAD_FLAG_ENDIANNESS << 0) | (HEAD_FLAG_PAGE_SIZE << 1) | (HEAD_FLAG_PHYS_BASE << 3))

/**
 * This is a generic entry point for an image. It carries out the operations required to prepare the
 * loaded image to be run. Specifically, it zeroes the bss section using registers x25 and above,
 * prepares the stack, enables floating point, and sets up the exception vector. It preserves x0-x3
 * for the Rust entry point, as these may contain boot parameters.
 */
.section .init.entry, "ax"
  /*
   * This header follows the AArch64 Linux kernel image header [1] to load
   * as a PE binary by the hypervisor.
   *
   * [1] https://docs.kernel.org/arch/arm64/booting.html
   */
  add x13, x18, #0x16      /* code0: UEFI "MZ" signature magic instruction */
  b entry          /* code1 */

  .quad 0x80000       /* text_offset */
  .quad bin_end - entry  /* image_size */
  .quad HEAD_FLAGS                /* flags */
  .quad 0                 /* res2 */
  .quad 0                 /* res3 */
  .quad 0                 /* res4 */

  .long 0x644d5241        /* "ARM\x64" magic number */
  .long 0                 /* res5 */
  .align 3

.global entry
entry:

    bl enable_mmu

    /* Disable trapping floating point access in EL1. */
    mrs x30, cpacr_el1
    orr x30, x30, #(0x3 << 20)
    msr cpacr_el1, x30
    isb

    /* Zero out the bss section. */
    adr_l x29, bss_begin
    adr_l x30, bss_end
0:  cmp x29, x30
    b.hs 1f
    stp xzr, xzr, [x29], #16
    b 0b

1:  /* Prepare the stack. */
    adr_l x30, boot_stack_end
    mov sp, x30

    /* Call into Rust code. */
    b rust_entry

/**
 * Entry point for secondary cores.
 *
 * This requires that an initial stack pointer value be passed in x0, and the stack must contain
 * the address of a Rust entry point to jump to and a parameter value to pass to it.
 */
.global secondary_entry
secondary_entry:
    bl enable_mmu

    /* Disable trapping floating point access in EL1. */
    mrs x30, cpacr_el1
    orr x30, x30, #(0x3 << 20)
    msr cpacr_el1, x30
    isb

    /* Set the stack pointer which was passed. */
    mov sp, x0

    /*
     * Load Rust entry point address and argument from the bottom of the stack into callee-saved
     * registers.
     */
    ldp x19, x20, [sp, #-16]

    /* Set the exception vector. */
    bl set_exception_vector

    /* Pass argument to Rust entry point. */
    mov x0, x19

    /* Call into Rust code. */
    br x20
