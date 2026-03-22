ROOT            := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
TOOLS_DIR       := $(ROOT)/tools

ARCH_FLAGS      := -march=rv32i -mabi=ilp32
COMMON_CFLAGS   := $(ARCH_FLAGS) -ffreestanding -fno-builtin -Wall -Wextra -Os

BUILD_DIR       := $(CURDIR)/build
OUT_BASENAME    ?= clock
MEM_OUT         ?= $(ROOT)/$(OUT_BASENAME).mem
COMMON_LDFLAGS  = $(ARCH_FLAGS) -nostdlib -Wl,-T,$(CURDIR)/linker.ld -Wl,-Map,$(BUILD_DIR)/$(OUT_BASENAME).map

ifneq ($(shell command -v riscv32-unknown-elf-gcc 2>/dev/null),)
CC       := riscv32-unknown-elf-gcc
OBJCOPY  := riscv32-unknown-elf-objcopy
OBJDUMP  := riscv32-unknown-elf-objdump
CFLAGS   := $(COMMON_CFLAGS)
LDFLAGS  := $(COMMON_LDFLAGS)
else ifneq ($(shell command -v riscv64-unknown-elf-gcc 2>/dev/null),)
CC       := riscv64-unknown-elf-gcc
OBJCOPY  := riscv64-unknown-elf-objcopy
OBJDUMP  := riscv64-unknown-elf-objdump
CFLAGS   := $(COMMON_CFLAGS)
LDFLAGS  := $(COMMON_LDFLAGS)
else ifneq ($(shell command -v clang 2>/dev/null),)
CC       := clang
OBJCOPY  := llvm-objcopy
OBJDUMP  := llvm-objdump
CFLAGS   := --target=riscv32-unknown-elf $(COMMON_CFLAGS)
# Add -fuse-ld=lld manually if your clang links RISC-V with lld (optional).
LDFLAGS  := --target=riscv32-unknown-elf $(COMMON_LDFLAGS)
else
$(error No suitable RISC-V toolchain found. Install riscv32-unknown-elf-gcc, riscv64-unknown-elf-gcc, or clang/LLVM with riscv32 support.)
endif

ELF      := $(BUILD_DIR)/$(OUT_BASENAME).elf
BIN      := $(BUILD_DIR)/$(OUT_BASENAME).bin
ASM      := $(BUILD_DIR)/$(OUT_BASENAME).lst

.PHONY: all clean smoke minroll hourroll dayroll

all: $(MEM_OUT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(ELF): start.S clock.c linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S clock.c

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(ASM): $(ELF)
	$(OBJDUMP) -d $< > $@

$(MEM_OUT): $(BIN) $(TOOLS_DIR)/bin2mem.py
	python3 $(TOOLS_DIR)/bin2mem.py $(BIN) $@
	$(MAKE) $(ASM)

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(ROOT)/clock*.mem