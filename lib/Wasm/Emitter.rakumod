use v6.d;
use LEB128;
use Wasm::Emitter::Data;
use Wasm::Emitter::Elements;
use Wasm::Emitter::Exports;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Function;
use Wasm::Emitter::Global;
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

    #| Table imports.
    has Wasm::Emitter::TableImport @!table-imports;

    #| Memory imports.
    has Wasm::Emitter::MemoryImport @!memory-imports;

    #| Global imports.
    has Wasm::Emitter::GlobalImport @!global-imports;

    #| Declared tables, with their table types.
    has Wasm::Emitter::Types::TableType @!tables;

    #| Declared memories, with their limits.
    has Wasm::Emitter::Types::LimitType @!memories;

    #| Declared exports.
    has Wasm::Emitter::Export @!exports;

    #| Declared data sections.
    has Wasm::Emitter::Data @!data;

    #| Declared globals.
    has Wasm::Emitter::Global @!globals;

    #| Declared elements.
    has Wasm::Emitter::Elements @!elements;

    #| Declared functions.
    has Wasm::Emitter::Function @!functions;

    #| Returns a type index for a function type. If the function type was
    #| already registered, returns the existing index; failing that, adds
    #| it under a new index.
    method function-type(Wasm::Emitter::Types::FunctionType $type --> Int) {
        for @!function-types.kv -> Int $idx, Wasm::Emitter::Types::FunctionType $existing {
            return $idx if $existing.same-as($type);
        }
        @!function-types.push($type);
        @!function-types.end
    }

    #| Add a function import.
    method import-function(Str $module, Str $name, Int $type-index --> Int) {
        if @!functions {
            die 'All function imports must be performed before any function declarations';
        }
        if $type-index < 0 || $type-index >= @!function-types.elems {
            die "Type index out of range";
        }
        @!function-imports.push: Wasm::Emitter::FunctionImport.new(:$module, :$name, :$type-index);
        @!function-imports.end
    }

    #| Add a table import.
    method import-table(Str $module, Str $name, Wasm::Emitter::Types::TableType $table-type --> Int) {
        if @!tables {
            die 'All table imports must be performed before any table declarations';
        }
        @!table-imports.push: Wasm::Emitter::TableImport.new(:$module, :$name, :$table-type);
        @!table-imports.end
    }

    #| Add a memory import.
    method import-memory(Str $module, Str $name, Wasm::Emitter::Types::LimitType $memory-type --> Int) {
        if @!memories {
            die 'All memory imports must be performed before any memory declarations';
        }
        @!memory-imports.push: Wasm::Emitter::MemoryImport.new(:$module, :$name, :$memory-type);
        @!memory-imports.end
    }

    #| Add a global import.
    method import-global(Str $module, Str $name, Wasm::Emitter::Types::GlobalType $global-type --> Int) {
        if @!globals {
            die 'All global imports must be performed before any global declarations';
        }
        @!global-imports.push: Wasm::Emitter::GlobalImport.new(:$module, :$name, :$global-type);
        @!global-imports.end
    }

    #| Declare a table.
    method table(Wasm::Emitter::Types::TableType $table-type --> Int) {
        @!tables.push($table-type);
        @!table-imports.elems + @!tables.end
    }

    #| Add a declaration of a memory.
    method memory(Wasm::Emitter::Types::LimitType $limits --> Int) {
        @!memories.push($limits);
        @!memory-imports.elems + @!memories.end
    }

    #| Export a function.
    method export-function(Str $name, Int $function-index --> Nil) {
        if $function-index < 0 || $function-index >= (@!function-imports.elems + @!functions.elems) {
            die "Function index out of range";
        }
        @!exports.push: Wasm::Emitter::FunctionExport.new(:$name, :$function-index);
    }

    #| Export a memory.
    method export-memory(Str $name, Int $memory-index --> Nil) {
        if $memory-index < 0 || $memory-index >= @!memories.elems {
            die "Memory index out of range";
        }
        @!exports.push: Wasm::Emitter::MemoryExport.new(:$name, :$memory-index);
    }

    #| Export a global.
    method export-global(Str $name, Int $global-index --> Nil) {
        if $global-index < 0 || $global-index >= @!globals.elems {
            die "Global index out of range";
        }
        @!exports.push: Wasm::Emitter::GlobalExport.new(:$name, :$global-index);
    }

    #| Export a table.
    method export-table(Str $name, Int $table-index --> Nil) {
        if $table-index < 0 || $table-index >= @!tables.elems {
            die "Table index out of range";
        }
        @!exports.push: Wasm::Emitter::TableExport.new(:$name, :$table-index);
    }

    #| Declare a passive data section.
    method passive-data(Blob $data --> Int) {
        @!data.push: Wasm::Emitter::Data::Passive.new(:$data);
        @!data.end
    }

    #| Declare an active data section.
    method active-data(Blob $data, Wasm::Emitter::Expression $offset --> Int) {
        @!data.push: Wasm::Emitter::Data::Active.new(:$data, :$offset);
        @!data.end
    }

    #| Declare a global.
    method global(Wasm::Emitter::Types::GlobalType $type, Wasm::Emitter::Expression $init --> Int) {
        @!globals.push: Wasm::Emitter::Global.new(:$type, :$init);
        @!global-imports.elems + @!globals.end
    }

    #| Declare an elements section.
    method elements(Wasm::Emitter::Elements $elements --> Int) {
        @!elements.push($elements);
        @!elements.end
    }

    #| Declare a function.
    method function(Wasm::Emitter::Function $function --> Int) {
        @!functions.push($function);
        @!function-imports.elems + @!functions.end
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
        if @!function-imports || @!table-imports || @!memory-imports || @!global-imports {
            my $import-section = self!assemble-import-section();
            $output.write-uint8($pos++, 2);
            $pos += encode-leb128-unsigned($import-section.elems, $output, $pos);
            $output.append($import-section);
            $pos += $import-section.elems;
        }
        if @!functions {
            my $func-section = self!assemble-function-section();
            $output.write-uint8($pos++, 3);
            $pos += encode-leb128-unsigned($func-section.elems, $output, $pos);
            $output.append($func-section);
            $pos += $func-section.elems;
        }
        if @!tables {
            my $table-section = self!assemble-table-section();
            $output.write-uint8($pos++, 4);
            $pos += encode-leb128-unsigned($table-section.elems, $output, $pos);
            $output.append($table-section);
            $pos += $table-section.elems;
        }
        if @!memories {
            my $memory-section = self!assemble-memory-section();
            $output.write-uint8($pos++, 5);
            $pos += encode-leb128-unsigned($memory-section.elems, $output, $pos);
            $output.append($memory-section);
            $pos += $memory-section.elems;
        }
        if @!globals {
            my $global-section = self!assemble-global-section();
            $output.write-uint8($pos++, 6);
            $pos += encode-leb128-unsigned($global-section.elems, $output, $pos);
            $output.append($global-section);
            $pos += $global-section.elems;
        }
        if @!exports {
            my $export = self!assemble-export-section();
            $output.write-uint8($pos++, 7);
            $pos += encode-leb128-unsigned($export.elems, $output, $pos);
            $output.append($export);
            $pos += $export.elems;
        }
        if @!elements {
            my $elements = self!assemble-element-section();
            $output.write-uint8($pos++, 9);
            $pos += encode-leb128-unsigned($elements.elems, $output, $pos);
            $output.append($elements);
            $pos += $elements.elems;
        }
        if @!data {
            my $data-count = self!assemble-data-count-section();
            $output.write-uint8($pos++, 12);
            $pos += encode-leb128-unsigned($data-count.elems, $output, $pos);
            $output.append($data-count);
            $pos += $data-count.elems;
        }
        if @!functions {
            my $code-section = self!assemble-code-section();
            $output.write-uint8($pos++, 10);
            $pos += encode-leb128-unsigned($code-section.elems, $output, $pos);
            $output.append($code-section);
            $pos += $code-section.elems;
        }
        if @!data {
            my $data = self!assemble-data-section();
            $output.write-uint8($pos++, 11);
            $pos += encode-leb128-unsigned($data.elems, $output, $pos);
            $output.append($data);
            $pos += $data.elems;
        }

        $output
    }

    method !assemble-type-section(--> Buf) {
        assemble-simple-section(@!function-types)
    }

    method !assemble-import-section(--> Buf) {
        my @imports = flat @!function-imports, @!table-imports, @!memory-imports, @!global-imports;
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(@imports.elems, $output, $pos);
        for @imports {
            $pos += .emit($output, $pos);
        }
        return $output;
    }

    method !assemble-function-section(--> Buf) {
        my $output = Buf.new;
        my int $pos = 0;
        $pos += encode-leb128-unsigned(@!functions.elems, $output, $pos);
        for @!functions {
            $pos += encode-leb128-unsigned(.type-index, $output, $pos);
        }
        return $output;
    }

    method !assemble-table-section(--> Buf) {
        assemble-simple-section(@!tables)
    }

    method !assemble-memory-section(--> Buf) {
        assemble-simple-section(@!memories)
    }

    method !assemble-global-section(--> Buf) {
        assemble-simple-section(@!globals)
    }

    method !assemble-export-section(--> Buf) {
        assemble-simple-section(@!exports)
    }

    method !assemble-element-section(--> Buf) {
        assemble-simple-section(@!elements)
    }

    method !assemble-data-count-section(--> Buf) {
        return encode-leb128-unsigned(@!data.elems);
    }

    method !assemble-code-section(--> Buf) {
        assemble-simple-section(@!functions)
    }

    method !assemble-data-section(--> Buf) {
        assemble-simple-section(@!data)
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
