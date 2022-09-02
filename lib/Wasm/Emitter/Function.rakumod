use v6.d;
use LEB128;
use Wasm::Emitter::Expression;

#| A WebAssembly function.
class Wasm::Emitter::Function {
    #| The index of the function type.
    has Int $.type-index is required;

    #| The expression making up the function body.
    has Wasm::Emitter::Expression $.expression is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        my $locals = self!form-locals();
        my $code-expr = $!expression.assemble();
        my $size = $locals.elems + $code-expr.elems;
        $pos += encode-leb128-unsigned($size, $into, $pos);
        $into.append($locals);
        $into.append($code-expr);
        $pos - $offset
    }

    method !form-locals(--> Buf) {
        # Locals NYI, so just return an empty vector.
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(0, $output, $pos);
        return $output;
    }
}
