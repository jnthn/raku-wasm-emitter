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
    has Bool $!assembled = False;

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

    method call-indirect(Int $type-index, Int $table-index --> Nil) {
        $!code.write-uint8($!pos++, 0x11);
        $!pos += encode-leb128-unsigned($type-index, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-index, $!code, $!pos);
    }

    method ref-null(Wasm::Emitter::Types::ReferenceType $type --> Nil) {
        $!code.write-uint8($!pos++, 0xD0);
        $!pos += $type.emit($!code, $!pos);
    }

    method ref-is-null(--> Nil) {
        $!code.write-uint8($!pos++, 0xD1);
    }

    method ref-func(Int $function-index --> Nil) {
        $!code.write-uint8($!pos++, 0xD2);
        $!pos += encode-leb128-unsigned($function-index, $!code, $!pos);
    }

    method drop(--> Nil) {
        $!code.write-uint8($!pos++, 0x1A);
    }

    method select(Wasm::Emitter::Types::ValueType $type? --> Nil) {
        with $type {
            $!code.write-uint8($!pos++, 0x1C);
            $!pos += encode-leb128-unsigned(1, $!code, $!pos);
            $!pos += $type.emit($!code, $!pos);
        }
        else {
            $!code.write-uint8($!pos++, 0x1B);
        }
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

    method global-get(Int $global-idx --> Nil) {
        $!code.write-uint8($!pos++, 0x23);
        $!pos += encode-leb128-unsigned($global-idx, $!code, $!pos);
    }

    method global-set(Int $global-idx --> Nil) {
        $!code.write-uint8($!pos++, 0x24);
        $!pos += encode-leb128-unsigned($global-idx, $!code, $!pos);
    }

    method table-get(Int $table-idx --> Nil) {
        $!code.write-uint8($!pos++, 0x25);
        $!pos += encode-leb128-unsigned($table-idx, $!code, $!pos);
    }

    method table-set(Int $table-idx --> Nil) {
        $!code.write-uint8($!pos++, 0x26);
        $!pos += encode-leb128-unsigned($table-idx, $!code, $!pos);
    }

    method table-copy(Int $table-idx-dst, Int $table-idx-src --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(14, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-idx-dst, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-idx-src, $!code, $!pos);
    }

    method table-grow(Int $table-idx --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(15, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-idx, $!code, $!pos);
    }

    method table-size(Int $table-idx --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(16, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-idx, $!code, $!pos);
    }

    method table-fill(Int $table-idx --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(17, $!code, $!pos);
        $!pos += encode-leb128-unsigned($table-idx, $!code, $!pos);
    }

    method i32-load(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x28);
        self!mem-arg($align, $offset);
    }

    method i64-load(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x29);
        self!mem-arg($align, $offset);
    }

    method f32-load(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2A);
        self!mem-arg($align, $offset);
    }

    method f64-load(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2B);
        self!mem-arg($align, $offset);
    }

    method i32-load8-s(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2C);
        self!mem-arg($align, $offset);
    }

    method i32-load8-u(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2D);
        self!mem-arg($align, $offset);
    }

    method i32-load16-s(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2E);
        self!mem-arg($align, $offset);
    }

    method i32-load16-u(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x2F);
        self!mem-arg($align, $offset);
    }

    method i64-load8-s(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x30);
        self!mem-arg($align, $offset);
    }

    method i64-load8-u(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x31);
        self!mem-arg($align, $offset);
    }

    method i64-load16-s(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x32);
        self!mem-arg($align, $offset);
    }

    method i64-load16-u(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x33);
        self!mem-arg($align, $offset);
    }

    method i64-load32-s(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x34);
        self!mem-arg($align, $offset);
    }

    method i64-load32-u(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x35);
        self!mem-arg($align, $offset);
    }

    method i32-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x36);
        self!mem-arg($align, $offset);
    }

    method i64-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x37);
        self!mem-arg($align, $offset);
    }

    method f32-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x38);
        self!mem-arg($align, $offset);
    }

    method f64-store(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x39);
        self!mem-arg($align, $offset);
    }

    method i32-store8(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x3A);
        self!mem-arg($align, $offset);
    }

    method i32-store16(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x3B);
        self!mem-arg($align, $offset);
    }

    method i64-store8(Int :$align = 0, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x3C);
        self!mem-arg($align, $offset);
    }

    method i64-store16(Int :$align = 1, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x3D);
        self!mem-arg($align, $offset);
    }

    method i64-store32(Int :$align = 2, Int :$offset = 0 --> Nil) {
        $!code.write-uint8($!pos++, 0x3E);
        self!mem-arg($align, $offset);
    }

    method !mem-arg(Int $align, Int $offset --> Nil) {
        $!pos += encode-leb128-unsigned($align, $!code, $!pos);
        $!pos += encode-leb128-unsigned($offset, $!code, $!pos);
    }

    method memory-size(--> Nil) {
        $!code.write-uint8($!pos++, 0x3F);
        $!code.write-uint8($!pos++, 0x00);
    }

    method memory-grow(--> Nil) {
        $!code.write-uint8($!pos++, 0x40);
        $!code.write-uint8($!pos++, 0x00);
    }

    method memory-init(Int $data-idx --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(8, $!code, $!pos);
        $!pos += encode-leb128-unsigned($data-idx, $!code, $!pos);
        $!code.write-uint8($!pos++, 0x00);
    }

    method data-drop(Int $data-idx --> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(9, $!code, $!pos);
        $!pos += encode-leb128-unsigned($data-idx, $!code, $!pos);
    }

    method memory-copy(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(10, $!code, $!pos);
        $!code.write-uint8($!pos++, 0x00);
        $!code.write-uint8($!pos++, 0x00);
    }

    method memory-fill(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(11, $!code, $!pos);
        $!code.write-uint8($!pos++, 0x00);
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

    method i32-wrap-i64(--> Nil) {
        $!code.write-uint8($!pos++, 0xA7);
    }

    method i32-trunc-f32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xA8);
    }

    method i32-trunc-f32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xA9);
    }

    method i32-trunc-f64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xAA);
    }

    method i32-trunc-f64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xAB);
    }

    method i64-extend-i32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xAC);
    }

    method i64-extend-i32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xAD);
    }

    method i64-trunc-f32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xAE);
    }

    method i64-trunc-f32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xAF);
    }

    method i64-trunc-f64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xB0);
    }

    method i64-trunc-f64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xB1);
    }

    method f32-convert-i32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xB2);
    }

    method f32-convert-i32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xB3);
    }

    method f32-convert-i64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xB4);
    }

    method f32-convert-i64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xB5);
    }

    method f32-demote-f64(--> Nil) {
        $!code.write-uint8($!pos++, 0xB6);
    }

    method f64-convert-i32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xB7);
    }

    method f64-convert-i32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xB8);
    }

    method f64-convert-i64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xB9);
    }

    method f64-convert-i64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xBA);
    }

    method f64-promote-f32(--> Nil) {
        $!code.write-uint8($!pos++, 0xBB);
    }

    method i32-reinterpret-f32(--> Nil) {
        $!code.write-uint8($!pos++, 0xBC);
    }

    method i64-reinterpret-f64(--> Nil) {
        $!code.write-uint8($!pos++, 0xBD);
    }

    method f32-reinterpret-i32(--> Nil) {
        $!code.write-uint8($!pos++, 0xBE);
    }

    method f64-reinterpret-i64(--> Nil) {
        $!code.write-uint8($!pos++, 0xBF);
    }

    method i32-extend8-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xC0);
    }

    method i32-extend16-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xC1);
    }

    method i64-extend8-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xC2);
    }

    method i64-extend16-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xC3);
    }

    method i64-extend32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xC4);
    }

    method i32-trunc-sat-f32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(0, $!code, $!pos);
    }

    method i32-trunc-sat-f32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(1, $!code, $!pos);
    }

    method i32-trunc-sat-f64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(2, $!code, $!pos);
    }

    method i32-trunc-sat-f64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(3, $!code, $!pos);
    }

    method i64-trunc-sat-f32-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(4, $!code, $!pos);
    }

    method i64-trunc-sat-f32-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(5, $!code, $!pos);
    }

    method i64-trunc-sat-f64-s(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(6, $!code, $!pos);
    }

    method i64-trunc-sat-f64-u(--> Nil) {
        $!code.write-uint8($!pos++, 0xFC);
        $!pos += encode-leb128-unsigned(7, $!code, $!pos);
    }

    method assemble(--> Buf) {
        unless $!assembled {
            $!code.write-uint8($!pos++, 0x0B);
            $!assembled = True;
        }
        $!code
    }
}
