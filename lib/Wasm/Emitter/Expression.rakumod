use v6.d;
use LEB128;

#| Writer for a WebAssembly expression. Used to emit a sequence of instructions.
#| Automatically adds the end marker when the expression's value is requested.
class Wasm::Emitter::Expression {
    has Buf $!code .= new;
    has int $!pos = 0;

    method call(Int $function-index --> Nil) {
        $!code.write-uint8($!pos++, 0x10);
        $!pos += encode-leb128-unsigned($function-index, $!code, $!pos);
    }

    method drop(--> Nil) {
        $!code.write-uint8($!pos++, 0x1A);
    }

    method local-get(Int $local-index --> Nil) {
        $!code.write-uint8($!pos++, 0x20);
        $!pos += encode-leb128-unsigned($local-index, $!code, $!pos);
    }

    method local-set(Int $local-index --> Nil) {
        $!code.write-uint8($!pos++, 0x21);
        $!pos += encode-leb128-unsigned($local-index, $!code, $!pos);
    }

    method local-tee(Int $local-index --> Nil) {
        $!code.write-uint8($!pos++, 0x22);
        $!pos += encode-leb128-unsigned($local-index, $!code, $!pos);
    }

    method i32-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x36);
        self!mem-arg($align, $offset);
    }

    method i64-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x37);
        self!mem-arg($align, $offset);
    }

    method !mem-arg(Int $align, Int $offset --> Nil) {
        $!pos += encode-leb128-unsigned($align, $!code, $!pos);
        $!pos += encode-leb128-unsigned($offset, $!code, $!pos);
    }

    method i32-const(Int $value --> Nil) {
        $!code.write-uint8($!pos++, 0x41);
        $!pos += encode-leb128-signed($value, $!code, $!pos);
    }

    method i64-const(Int $value --> Nil) {
        $!code.write-uint8($!pos++, 0x42);
        $!pos += encode-leb128-signed($value, $!code, $!pos);
    }

    method f32-const(Num $value --> Nil) {
        $!code.write-uint8($!pos++, 0x43);
        $!code.write-num32($!pos, $value, Endian::LittleEndian);
        $!pos += 4;
    }

    method f64-const(Num $value --> Nil) {
        $!code.write-uint8($!pos++, 0x44);
        $!code.write-num64($!pos, $value, Endian::LittleEndian);
        $!pos += 8;
    }

    method f32-eq(--> Nil) {
        $!code.write-uint8($!pos++, 0x5B);
    }

    method f32-ne(--> Nil) {
        $!code.write-uint8($!pos++, 0x5C);
    }

    method f32-lt(--> Nil) {
        $!code.write-uint8($!pos++, 0x5D);
    }

    method f32-gt(--> Nil) {
        $!code.write-uint8($!pos++, 0x5E);
    }

    method f32-le(--> Nil) {
        $!code.write-uint8($!pos++, 0x5F);
    }

    method f32-ge(--> Nil) {
        $!code.write-uint8($!pos++, 0x60);
    }

    method f64-eq(--> Nil) {
        $!code.write-uint8($!pos++, 0x61);
    }

    method f64-ne(--> Nil) {
        $!code.write-uint8($!pos++, 0x62);
    }

    method f64-lt(--> Nil) {
        $!code.write-uint8($!pos++, 0x63);
    }

    method f64-gt(--> Nil) {
        $!code.write-uint8($!pos++, 0x64);
    }

    method f64-le(--> Nil) {
        $!code.write-uint8($!pos++, 0x65);
    }

    method f64-ge(--> Nil) {
        $!code.write-uint8($!pos++, 0x66);
    }

    method assemble(--> Buf) {
        $!code.write-uint8($!pos++, 0x0B);
        $!code
    }
}
