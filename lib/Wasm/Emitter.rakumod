use v6.d;
use LEB128;
use Wasm::Emitter::Exports;
use Wasm::Emitter::Imports;
use Wasm::Emitter::Types;

#| Emitter for a binary Wasm module. An instance of this represents a module.
#| Make the various declarations, and then call C<assemble> to produce a
#| C<Buf> with the WebAssembly.
class Wasm::Emitter {
    #| Function types, all distinct.
    has Wasm::Emitter::Types::FunctionType @!function-types;

    #| Function imports.
    has Wasm::Emitter::FunctionImport @!function-imports;

    #| Declared memories, with their limits.
    has Wasm::Emitter::Types::LimitType @!memories;

    #| Declared exports.
    has Wasm::Emitter::Export @!exports;

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

    #| Add a function import.
    method import-function(Str $module, Str $name, Int $type-index --> Int) {
        if $type-index < 0 || $type-index >= @!function-types.elems {
            die "Type index out of range";
        }
        @!function-imports.push: Wasm::Emitter::FunctionImport.new(:$module, :$name, :$type-index);
        @!function-imports.end
    }

    #| Add a declaration of a memory.
    method add-memory(Wasm::Emitter::Types::LimitType $limits --> Int) {
        @!memories.push($limits);
        @!memories.end
    }

    #| Export a memory.
    method export-memory(Str $name, Int $memory-index --> Nil) {
        if $memory-index < 0 || $memory-index >= @!memories.elems {
            die "Memory index out of range";
        }
        @!exports.push: Wasm::Emitter::MemoryExport.new(:$name, :$memory-index);
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
            $pos += $type-section.elems;
        }
        if @!function-imports #`( TODO et al ) {
            my $import-section = self!assemble-import-section();
            $output.write-uint8($pos++, 2);
            $pos += encode-leb128-unsigned($import-section.elems, $output, $pos);
            $output.append($import-section);
            $pos += $import-section.elems;
        }
        if @!memories {
            my $memory-section = self!assemble-memory-section();
            $output.write-uint8($pos++, 5);
            $pos += encode-leb128-unsigned($memory-section.elems, $output, $pos);
            $output.append($memory-section);
            $pos += $memory-section.elems;
        }
        if @!exports {
            my $export = self!assemble-export-section();
            $output.write-uint8($pos++, 7);
            $pos += encode-leb128-unsigned($export.elems, $output, $pos);
            $output.append($export);
            $pos += $export.elems;
        }

        $output
    }

    method !assemble-type-section(--> Buf) {
        assemble-simple-section(@!function-types)
    }

    method !assemble-import-section(--> Buf) {
        my $output = Buf.new;
        my int $pos = 0;
        my uint $import-count = [+] @!function-imports.elems; #`( TODO et al )
        $pos += encode-leb128-unsigned($import-count, $output, $pos);
        for @!function-imports {
            $pos += .emit($output, $pos);
        }
        return $output;
    }

    method !assemble-memory-section(--> Buf) {
        assemble-simple-section(@!memories)
    }

    method !assemble-export-section(--> Buf) {
        assemble-simple-section(@!exports)
    }

    sub assemble-simple-section(@elements --> Buf) {
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(@elements.elems, $output, $pos);
        for @elements {
            $pos += .emit($output, $pos);
        }
        return $output;
    }
}
