use v6.d;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Types;

#| A WebAssembly global declaration.
class Wasm::Emitter::Global {
    has Wasm::Emitter::Types::GlobalType $.type is required;
    has Wasm::Emitter::Expression $.init is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += $!type.emit($into, $pos);
        my $init-expr = $!init.assemble();
        $into.append($init-expr);
        $pos += $init-expr.elems;
        $pos - $offset
    }
}
