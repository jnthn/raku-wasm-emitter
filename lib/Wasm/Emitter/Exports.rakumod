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
}
