use v6.d;
use LEB128;
use Wasm::Emitter::Types;

#| A block type, if provided, is either a value type or an integer or a type object
#| (where the type object signifies the absence of a block type).
subset Wasm::Emitter::BlockType where Wasm::Emitter::Types::ValueType:D | Int:D | Any:U;

#| Writer for a WebAssembly expression. Used to emit a sequence of instructions.
#| Automatically adds the end marker when the expression's value is requested.
class Wasm::Emitter::Expression {
    has Buf $!code .= new;
    has int $!pos = 0;

    method unreachable(--> Nil) {
        $!code.write-uint8($!pos++, 0x00);
    }

    method nop(--> Nil) {
        $!code.write-uint8($!pos++, 0x01);
    }

    method block(&body, Wasm::Emitter::BlockType :$blocktype --> Nil) {
        $!code.write-uint8($!pos++, 0x02);
        self!emit-blocktype($blocktype);
        body();
        $!code.write-uint8($!pos++, 0x0B);
    }

    method loop(&body, Wasm::Emitter::BlockType :$blocktype --> Nil) {
        $!code.write-uint8($!pos++, 0x03);
        self!emit-blocktype($blocktype);
        body();
        $!code.write-uint8($!pos++, 0x0B);
    }

    method if(&then, &else?, Wasm::Emitter::BlockType :$blocktype --> Nil) {
        $!code.write-uint8($!pos++, 0x04);
        self!emit-blocktype($blocktype);
        then();
        with &else {
            $!code.write-uint8($!pos++, 0x05);
            else();
        }
        $!code.write-uint8($!pos++, 0x0B);
    }

    method !emit-blocktype(Wasm::Emitter::BlockType $block-type --> Nil) {
        with $block-type {
            when Wasm::Emitter::Types::ValueType {
                $!pos += .emit($!code, $!pos);
            }
            when Int {
                $!pos += encode-leb128-signed($_, $!code, $!pos);
            }
            default {
                die "Unexpected block type {.^name}";
            }
        }
        else {
            $!code.write-uint8($!pos++, 0x40);
        }
    }

    method br(Int $label-index = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x0C);
        $!pos += encode-leb128-unsigned($label-index, $!code, $!pos);
    }

    method br-if(Int $label-index = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x0D);
        $!pos += encode-leb128-unsigned($label-index, $!code, $!pos);
    }

    method br-table(@cases, Int $default --> Nil) {
        $!code.write-uint8($!pos++, 0x0E);
        $!pos += encode-leb128-unsigned(@cases.elems, $!code, $!pos);
        $!pos += encode-leb128-unsigned($_, $!code, $!pos) for @cases;
        $!pos += encode-leb128-unsigned($default, $!code, $!pos)
    }

    method return(--> Nil) {
        $!code.write-uint8($!pos++, 0x0F);
    }

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

    method i32-eqz(--> Nil) {
        $!code.write-uint8($!pos++, 0x45);
    }

    method i32-eq(--> Nil) {
        $!code.write-uint8($!pos++, 0x46);
    }

    method i32-ne(--> Nil) {
        $!code.write-uint8($!pos++, 0x47);
    }

    method i32-lt-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x48);
    }

    method i32-lt-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x49);
    }

    method i32-gt-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x4A);
    }

    method i32-gt-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x4B);
    }

    method i32-le-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x4C);
    }

    method i32-le-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x4D);
    }

    method i32-ge-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x4E);
    }

    method i32-ge-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x4F);
    }

    method i64-eqz(--> Nil) {
        $!code.write-uint8($!pos++, 0x50);
    }

    method i64-eq(--> Nil) {
        $!code.write-uint8($!pos++, 0x51);
    }

    method i64-ne(--> Nil) {
        $!code.write-uint8($!pos++, 0x52);
    }

    method i64-lt-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x53);
    }

    method i64-lt-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x54);
    }

    method i64-gt-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x55);
    }

    method i64-gt-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x56);
    }

    method i64-le-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x57);
    }

    method i64-le-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x58);
    }

    method i64-ge-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x59);
    }

    method i64-ge-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x5A);
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

    method i32-clz(--> Nil) {
        $!code.write-uint8($!pos++, 0x67);
    }

    method i32-ctz(--> Nil) {
        $!code.write-uint8($!pos++, 0x68);
    }

    method i32-popcnt(--> Nil) {
        $!code.write-uint8($!pos++, 0x69);
    }

    method i32-add(--> Nil) {
        $!code.write-uint8($!pos++, 0x6A);
    }

    method i32-sub(--> Nil) {
        $!code.write-uint8($!pos++, 0x6B);
    }

    method i32-mul(--> Nil) {
        $!code.write-uint8($!pos++, 0x6C);
    }

    method i32-div-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x6D);
    }

    method i32-div-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x6E);
    }

    method i32-rem-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x6F);
    }

    method i32-rem-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x70);
    }

    method i32-and(--> Nil) {
        $!code.write-uint8($!pos++, 0x71);
    }

    method i32-or(--> Nil) {
        $!code.write-uint8($!pos++, 0x72);
    }

    method i32-xor(--> Nil) {
        $!code.write-uint8($!pos++, 0x73);
    }

    method i32-shl(--> Nil) {
        $!code.write-uint8($!pos++, 0x74);
    }

    method i32-shr-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x75);
    }

    method i32-shr-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x76);
    }

    method i32-rotl(--> Nil) {
        $!code.write-uint8($!pos++, 0x77);
    }

    method i32-rotr(--> Nil) {
        $!code.write-uint8($!pos++, 0x78);
    }

    method i64-clz(--> Nil) {
        $!code.write-uint8($!pos++, 0x79);
    }

    method i64-ctz(--> Nil) {
        $!code.write-uint8($!pos++, 0x7A);
    }

    method i64-popcnt(--> Nil) {
        $!code.write-uint8($!pos++, 0x7B);
    }

    method i64-add(--> Nil) {
        $!code.write-uint8($!pos++, 0x7C);
    }

    method i64-sub(--> Nil) {
        $!code.write-uint8($!pos++, 0x7D);
    }

    method i64-mul(--> Nil) {
        $!code.write-uint8($!pos++, 0x7E);
    }

    method i64-div-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x7F);
    }

    method i64-div-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x80);
    }

    method i64-rem-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x81);
    }

    method i64-rem-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x82);
    }

    method i64-and(--> Nil) {
        $!code.write-uint8($!pos++, 0x83);
    }

    method i64-or(--> Nil) {
        $!code.write-uint8($!pos++, 0x84);
    }

    method i64-xor(--> Nil) {
        $!code.write-uint8($!pos++, 0x85);
    }

    method i64-shl(--> Nil) {
        $!code.write-uint8($!pos++, 0x86);
    }

    method i64-shr-s(--> Nil) {
        $!code.write-uint8($!pos++, 0x87);
    }

    method i64-shr-u(--> Nil) {
        $!code.write-uint8($!pos++, 0x88);
    }

    method i64-rotl(--> Nil) {
        $!code.write-uint8($!pos++, 0x89);
    }

    method i64-rotr(--> Nil) {
        $!code.write-uint8($!pos++, 0x8A);
    }

    method f32-abs(--> Nil) {
        $!code.write-uint8($!pos++, 0x8B);
    }

    method f32-neg(--> Nil) {
        $!code.write-uint8($!pos++, 0x8C);
    }

    method f32-ceil(--> Nil) {
        $!code.write-uint8($!pos++, 0x8D);
    }

    method f32-floor(--> Nil) {
        $!code.write-uint8($!pos++, 0x8E);
    }

    method f32-trunc(--> Nil) {
        $!code.write-uint8($!pos++, 0x8F);
    }

    method f32-nearest(--> Nil) {
        $!code.write-uint8($!pos++, 0x90);
    }

    method f32-sqrt(--> Nil) {
        $!code.write-uint8($!pos++, 0x91);
    }

    method f32-add(--> Nil) {
        $!code.write-uint8($!pos++, 0x92);
    }

    method f32-sub(--> Nil) {
        $!code.write-uint8($!pos++, 0x93);
    }

    method f32-mul(--> Nil) {
        $!code.write-uint8($!pos++, 0x94);
    }

    method f32-div(--> Nil) {
        $!code.write-uint8($!pos++, 0x95);
    }

    method f32-min(--> Nil) {
        $!code.write-uint8($!pos++, 0x96);
    }

    method f32-max(--> Nil) {
        $!code.write-uint8($!pos++, 0x97);
    }

    method f32-copysign(--> Nil) {
        $!code.write-uint8($!pos++, 0x98);
    }

    method f64-abs(--> Nil) {
        $!code.write-uint8($!pos++, 0x99);
    }

    method f64-neg(--> Nil) {
        $!code.write-uint8($!pos++, 0x9A);
    }

    method f64-ceil(--> Nil) {
        $!code.write-uint8($!pos++, 0x9B);
    }

    method f64-floor(--> Nil) {
        $!code.write-uint8($!pos++, 0x9C);
    }

    method f64-trunc(--> Nil) {
        $!code.write-uint8($!pos++, 0x9D);
    }

    method f64-nearest(--> Nil) {
        $!code.write-uint8($!pos++, 0x9E);
    }

    method f64-sqrt(--> Nil) {
        $!code.write-uint8($!pos++, 0x9F);
    }

    method f64-add(--> Nil) {
        $!code.write-uint8($!pos++, 0xA0);
    }

    method f64-sub(--> Nil) {
        $!code.write-uint8($!pos++, 0xA1);
    }

    method f64-mul(--> Nil) {
        $!code.write-uint8($!pos++, 0xA2);
    }

    method f64-div(--> Nil) {
        $!code.write-uint8($!pos++, 0xA3);
    }

    method f64-min(--> Nil) {
        $!code.write-uint8($!pos++, 0xA4);
    }

    method f64-max(--> Nil) {
        $!code.write-uint8($!pos++, 0xA5);
    }

    method f64-copysign(--> Nil) {
        $!code.write-uint8($!pos++, 0xA6);
    }

    method assemble(--> Buf) {
        $!code.write-uint8($!pos++, 0x0B);
        $!code
    }
}
