use v6.d;
use LEB128;
use Wasm::Emitter::Expression;

#| Base of WebAssembly data sections.
role Wasm::Emitter::Data {
    has Blob $.data is required;

    method emit(Buf $into, uint $offset --> uint) { ... }
}

#| A passive WebAssembly data section (loaded on demand).
class Wasm::Emitter::Data::Passive does Wasm::Emitter::Data {
    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += encode-leb128-unsigned(1, $into, $pos);
        $pos += encode-leb128-unsigned($!data.elems, $into, $pos);
        $into.append($!data);
        $pos += $!data.elems;
        $pos - $offset
    }
}

#| An active WebAssembly data section (written into a memory at initialization).
class Wasm::Emitter::Data::Active does Wasm::Emitter::Data {
    has Wasm::Emitter::Expression $.offset is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += encode-leb128-unsigned(0, $into, $pos);
        my $offset-expr = $!offset.assemble();
        $into.append($offset-expr);
        $pos += $offset-expr.elems;
        $pos += encode-leb128-unsigned($!data.elems, $into, $pos);
        $into.append($!data);
        $pos += $!data.elems;
        $pos - $offset
    }
}
