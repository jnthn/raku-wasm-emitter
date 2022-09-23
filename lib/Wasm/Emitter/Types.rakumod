use v6.d;
use LEB128;
unit module Wasm::Emitter::Types;

#| Base of all WebAssembly types.
role Type {
    # Emit the type into the buffer at the specified offset. Return the
    # number of bytes written.
    method emit(Buf $into, uint $offset --> uint) { ... }
}

#| Base of all WebAssembly value types.
role ValueType does Type {
}

#| Base of all numeric types.
role NumericType does ValueType {}

#| 32-bit integer type.
class I32 does NumericType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x7F);
        1
    }
}

#| Create a 32-bit integer type.
sub i32() is export {
    BEGIN I32.new
}

#| 64-bit integer type.
class I64 does NumericType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x7E);
        1
    }
}

#| Create a 64-bit integer type.
sub i64() is export {
    BEGIN I64.new
}

#| 32-bit float type.
class F32 does NumericType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x7D);
        1
    }
}

#| Create a 32-bit float type.
sub f32() is export {
    BEGIN F32.new
}

#| 64-bit float type.
class F64 does NumericType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x7C);
        1
    }
}

#| Create a 64-bit float type.
sub f64() is export {
    BEGIN F64.new
}

#| Vector type.
class VectorType does ValueType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x7B);
        1
    }
}

#| Create a vector type.
sub vectype() is export {
    BEGIN VectorType.new
}

#| Base of reference types.
role ReferenceType does ValueType {
}

#| A function reference.
class FunctionReferenceType does ReferenceType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x70);
        1
    }
}

#| Create a function reference type.
sub funcref() is export {
    BEGIN FunctionReferenceType.new
}

#| An external reference.
class ExternalReferenceType does ReferenceType {
    method emit(Buf $into, uint $offset --> uint) {
        $into.write-uint8($offset, 0x6F);
        1
    }
}

#| Create an external reference type.
sub externref() is export {
    BEGIN ExternalReferenceType.new
}

#| A result type.
class ResultType does Type {
    has ValueType @.values is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += encode-leb128-unsigned(@!values.elems, $into, $pos);
        for @!values {
            $pos += .emit($into, $pos);
        }
        $pos - $offset
    }

    method same-as(ResultType $other --> Bool) {
        @!values.elems == $other.values.elems && so all @!values Z=== $other.values
    }
}

#| Create a result type.
sub resulttype(*@values) is export {
    ResultType.new(:@values)
}

#| A function type.
class FunctionType does Type {
    has ResultType $.in is required;
    has ResultType $.out is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $into.write-uint8($pos++, 0x60);
        $pos += $!in.emit($into, $pos);
        $pos += $!out.emit($into, $pos);
        $pos - $offset
    }

    method same-as(FunctionType $other --> Bool) {
        $!in.same-as($other.in) && $!out.same-as($other.out)
    }
}

#| Create a function type.
sub functype(ResultType $in, ResultType $out) is export {
    FunctionType.new(:$in, :$out)
}

#| A global type.
class GlobalType does Type {
    has ValueType $.value-type is required;
    has Bool $.mutable is required;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        $pos += $!value-type.emit($into, $pos);
        $into.write-uint8($pos++, $!mutable ?? 1 !! 0);
        $pos - $offset
    }
}

#| Create a global type.
sub globaltype(ValueType $value-type, Bool :$mutable = False) is export {
    GlobalType.new(:$value-type, :$mutable)
}

#| A limits type.
class LimitType does Type {
    has Int $.min is required;
    has Int $.max;

    method emit(Buf $into, uint $offset --> uint) {
        my int $pos = $offset;
        with $!max {
            $into.write-uint8($pos++, 0x01);
            $pos += encode-leb128-unsigned($!min, $into, $pos);
            $pos += encode-leb128-unsigned($!max, $into, $pos);
        }
        else {
            $into.write-uint8($pos++, 0x00);
            $pos += encode-leb128-unsigned($!min, $into, $pos);
        }
        $pos - $offset
    }
}

#| Create a limits type with a minimum and unbounded maximum.
multi sub limitstype(Int $min) is export {
    LimitType.new(:$min)
}

#| Create a limits type with a minimum and maximum.
multi sub limitstype(Int $min, Int $max) is export {
    LimitType.new(:$min, :$max)
}
