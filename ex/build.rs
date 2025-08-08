fn main() {
    println!("cargo:rustc-link-arg=-T./image.ld");
    println!("cargo:rustc-link-arg=-Tmemory.ld");
    println!("cargo:rerun-if-changed=memory.ld");
    println!("cargo:rerun-if-changed=image.ld");
}
