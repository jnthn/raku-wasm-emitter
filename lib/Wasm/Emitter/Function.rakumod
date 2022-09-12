use v6.d;
use LEB128;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Types;

#| A WebAssembly function.
class Wasm::Emitter::Function {
    #| The index of the function type.
    has Int $.type-index is required;

    #| The number of parameters.
    has Int $.parameters = 0;

    #| The expression making up the function body.
    has Wasm::Emitter::Expression $.expression is required;

    #| Declared locals.
    has Wasm::Emitter::Types::ValueType @!locals;

    #| Declare a local of the specified value type. Returns the index of the
    #| declared local.
    method declare-local(Wasm::Emitter::Types::ValueType $type --> Int) {
        @!locals.push($type);
        $!parameters + @!locals.end
    }

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
        # Compress locals by detecting sequences of identical types.
        my @run-length-encoded;
        my Wasm::Emitter::Types::ValueType $cur-type;
        my Int $cur-count = 0;
        for @!locals {
             if $_ !=== $cur-type {
                 @run-length-encoded.push($cur-type => $cur-count) if $cur-count;
                 $cur-count = 0;
            }
            $cur-type = $_;
            $cur-count++;
        }
        @run-length-encoded.push($cur-type => $cur-count) if $cur-count;

        # Emit compressed type vector.
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(@run-length-encoded.elems, $output, $pos);
        for @run-length-encoded {
            $pos += encode-leb128-unsigned(.value, $output, $pos);
            $pos += .key.emit($output, $pos);
        }
        return $output;
    }
}
