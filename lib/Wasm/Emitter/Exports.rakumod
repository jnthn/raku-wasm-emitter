use v6.d;
use LEB128;
use Wasm::Emitter::Name;

package Wasm::Emitter {
    #| An export of some kind.
    role Export {
        has Str $.name is required;

        method emit(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $pos += emit-name($into, $pos, $!name);
            $pos += self.emit-desc($into, $pos);
            $pos - $offset
        }

        method emit-desc(Buf $into, uint $offset --> uint) { ... }
    }

    #| A function export.
    class FunctionExport does Export {
        has Int $.function-index is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x00);
            $pos += encode-leb128-unsigned($!function-index, $into, $pos);
            $pos - $offset
        }
    }

    #| A memory export.
    class MemoryExport does Export {
        has Int $.memory-index is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x02);
            $pos += encode-leb128-unsigned($!memory-index, $into, $pos);
            $pos - $offset
        }
    }

    #| A global export.
    class GlobalExport does Export {
        has Int $.global-index is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x03);
            $pos += encode-leb128-unsigned($!global-index, $into, $pos);
            $pos - $offset
        }
    }

    #| A table export.
    class TableExport does Export {
        has Int $.table-index is required;

        method emit-desc(Buf $into, uint $offset --> uint) {
            my int $pos = $offset;
            $into.write-uint8($pos++, 0x01);
            $pos += encode-leb128-unsigned($!table-index, $into, $pos);
            $pos - $offset
        }
    }
}
