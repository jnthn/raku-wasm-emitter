use v6.d;
use LEB128;

#| Writer for a WebAssembly expression. Used to emit a sequence of instructions.
#| Automatically adds the end marker when the expression's value is requested.
class Wasm::Emitter::Expression {
    has Buf $!code .= new;
    has int $!pos = 0;

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
