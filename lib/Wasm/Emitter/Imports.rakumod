use v6.d;
use LEB128;
use Wasm::Emitter::Name;
use Wasm::Emitter::Types;

package Wasm::Emitter {
    #| An import of some kind.
    role Import {
        has Str $.module is required;
        has Str $.name is required;

        method emit(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $pos += emit-name($into, $pos, $!module);
            $pos += emit-name($into, $pos, $!name);
            $pos += self.emit-desc($into, $pos);
            $pos - $offset
        }

        method emit-desc(Buf $into, uint $offset --> uint) { ... }
    }

    #| A function import.
    class FunctionImport does Import {
        has Int $.type-index is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x00);
            $pos += encode-leb128-unsigned($!type-index, $into, $pos);
            $pos - $offset
        }
    }

    #| A table import.
    class TableImport does Import {
        has Wasm::Emitter::Types::TableType $.table-type is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x01);
            $pos += $!table-type.emit($into, $pos);
            $pos - $offset
        }
    }

    #| A memory import.
    class MemoryImport does Import {
        has Wasm::Emitter::Types::LimitType $.memory-type is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x02);
            $pos += $!memory-type.emit($into, $pos);
            $pos - $offset
        }
    }

    #| A global import.
    class GlobalImport does Import {
        has Wasm::Emitter::Types::GlobalType $.global-type is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x03);
            $pos += $!global-type.emit($into, $pos);
            $pos - $offset
        }
    }
}
