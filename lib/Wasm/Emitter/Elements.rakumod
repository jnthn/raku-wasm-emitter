use v6.d;
unit package Wasm::Emitter;
use LEB128;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Types;

#| The commonalities of all element segments.
role Elements {
    #| The type of reference.
    has Wasm::Emitter::Types::ReferenceType $.type is required;

    #| The initialization expressions of the elements.
    has Wasm::Emitter::Expression @.init is required;

    method emit(Buf $into, uint $offset --> uint) { ... }

    method !emit-init(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += encode-leb128-unsigned(@!init.elems, $into, $pos);
        for @!init {
            my $init-expr = .assemble();
            $into.append($init-expr);
            $pos += $init-expr.elems;
        }
        $pos - $offset
    }

    method !constant-func-ref-indexes() {
        my @indices;
        for @!init {
            with .get-constant-func-ref {
                @indices.push($_);
            }
            else {
                return Nil;
            }
        }
        @indices
    }
}

#| A declarative elements segment.
class Elements::Declarative does Elements {
    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        with self!constant-func-ref-indexes() -> @indices {
            $pos += encode-leb128-unsigned(3, $into, $pos);
            $pos += encode-leb128-unsigned(0, $into, $pos);
            $pos += encode-leb128-unsigned(@indices.elems, $into, $pos);
            for @indices {
                $pos += encode-leb128-unsigned($_, $into, $pos);
            }
        }
        else {
            $pos += encode-leb128-unsigned(7, $into, $pos);
            $pos += $!type.emit($into, $pos);
            $pos += self!emit-init($into, $pos);
        }
        $pos - $offset
    }
}

#| A passive elements segment.
class Elements::Passive does Elements {
    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        with self!constant-func-ref-indexes() -> @indices {
            $pos += encode-leb128-unsigned(1, $into, $pos);
            $pos += encode-leb128-unsigned(0, $into, $pos);
            $pos += encode-leb128-unsigned(@indices.elems, $into, $pos);
            for @indices {
                $pos += encode-leb128-unsigned($_, $into, $pos);
            }
        }
        else {
            $pos += encode-leb128-unsigned(5, $into, $pos);
            $pos += $!type.emit($into, $pos);
            $pos += self!emit-init($into, $pos);
        }
        $pos - $offset
    }
}

#| An active elements segment.
class Elements::Active does Elements {
    #| The table index to install the elements into.
    has Int $.table-index is required;

    #| An expression that evaluates to the offset.
    has Wasm::Emitter::Expression $.offset is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        if $!table-index == 0 && $!type === funcref() {
            with self!constant-func-ref-indexes() -> @indices {
                $pos += encode-leb128-unsigned(0, $into, $pos);
                my $offset-expr = $!offset.assemble();
                $into.append($offset-expr);
                $pos += $offset-expr.elems;
                $pos += encode-leb128-unsigned(@indices.elems, $into, $pos);
                for @indices {
                    $pos += encode-leb128-unsigned($_, $into, $pos);
                }
            }
            else {
                $pos += encode-leb128-unsigned(4, $into, $pos);
                my $offset-expr = $!offset.assemble();
                $into.append($offset-expr);
                $pos += $offset-expr.elems;
                $pos += self!emit-init($into, $pos);
            }
        }
        else {
            $pos += encode-leb128-unsigned(6, $into, $pos);
            $pos += encode-leb128-unsigned($!table-index, $into, $pos);
            my $offset-expr = $!offset.assemble();
            $into.append($offset-expr);
            $pos += $offset-expr.elems;
            $pos += $!type.emit($into, $pos);
            $pos += self!emit-init($into, $pos);
        }
        $pos - $offset
    }
}
