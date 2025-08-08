target := aarch64-unknown-none
mode := release
kernel := ./target/$(target)/$(mode)/ex
kernel_bin := ./target/$(target)/$(mode)/ex.bin

BUILD_ARGS += --target $(target)
ifeq ($(mode), release)
	BUILD_ARGS += --release
endif

$(kernel):
	cargo build $(BUILD_ARGS)

all: $(kernel_bin)

$(kernel_bin): $(kernel)
	aarch64-linux-gnu-objcopy -O binary $(kernel) $(kernel_bin)

qemu-tcg: $(kernel_bin)
	qemu-system-aarch64 \
		-machine virt,accel=tcg \
		-m 4G \
		-cpu max \
		-kernel $(kernel_bin) \
		-nic none -vga none \
		-nographic \
		-serial mon:stdio \
		-d guest_errors,in_asm,int -D qemu.log
