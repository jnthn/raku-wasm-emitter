use v6.d;
use LEB128;
use Wasm::Emitter::Types;

#| Emitter for a binary Wasm module. An instance of this represents a module.
#| Make the various declarations, and then call C<assemble> to produce a
#| C<Buf> with the WebAssembly.
class Wasm::Emitter {
    #| Function types, all distinct.
    has Wasm::Emitter::Types::FunctionType @!function-types;

    #| Returns a type index for a function type. If the function type was
    #| already registered, returns the existing index; failing that, adds
    #| it under a new index.
    method intern-function-type(Wasm::Emitter::Types::FunctionType $type --> Int) {
        for @!function-types.kv -> Int $idx, Wasm::Emitter::Types::FunctionType $existing {
            return $idx if $existing.same-as($type);
        }
        @!function-types.push($type);
        @!function-types.end
    }

    #| Assemble the produced declarations into a final output.
    method assemble(--> Buf) {
        # Emit header.
        my Buf $output = Buf.new;
        my int $pos = 0;
        for #`(magic) 0x00, 0x61, 0x73, 0x6D, #`(version) 0x01, 0x00, 0x00, 0x00 {
            $output.write-uint8($pos++, $_);
        }

        # Emit sections.
        if @!function-types {
            my $type-section = self!assemble-type-section();
            $output.write-uint8($pos++, 1);
            $pos += encode-leb128-unsigned($type-section.elems, $output, $pos);
            $output.append($type-section);
        }

        $output
    }

    method !assemble-type-section(--> Buf) {
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(@!function-types.elems, $output, $pos);
        for @!function-types {
            $pos += .emit($output, $pos);
        }
        return $output;
    }
}
