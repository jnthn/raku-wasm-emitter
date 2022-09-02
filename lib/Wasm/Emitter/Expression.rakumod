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

    method assemble(--> Buf) {
        $!code.write-uint8($!pos++, 0x0B);
        $!code
    }
}
