use v6.d;
use Wasm::Emitter;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Function;
use Wasm::Emitter::Types;
use Test;

sub has-wasmtime() {
    so qqx/wasmtime -h/
}

sub is-wasmtime-output(Buf $wasm, $expected) {
    # Write WASM to a temporary file.
    my $temp-file = $*TMPDIR.add("raku-wasm-$*PID.wasm");
    spurt $temp-file, $wasm;
    LEAVE try unlink $temp-file;

    # Try running it.
    my $exitcode = -1;
    my $output = '';
    react {
        my $proc = Proc::Async.new('wasmtime', $temp-file);
        whenever $proc.stdout {
            $output ~= $_;
        }
        whenever $proc.stderr.lines {
            diag $_;
        }
        whenever $proc.start {
            $exitcode = .exitcode;
        }
    }

    # Analyze results.
    is $exitcode, 0, "wasmtime exitted successfully";
    ok $output ~~ $expected, "Correct output";
}

if has-wasmtime() {
    subtest 'Empty' => {
        my $emitter = Wasm::Emitter.new;
        my $buf = $emitter.assemble();
        pass 'Assembled empty module';
        is-wasmtime-output $buf, '';
    }

    subtest 'Function types' => {
        my $emitter = Wasm::Emitter.new;
        is $emitter.intern-function-type(functype(resulttype(i64(), i32()), resulttype(i64()))),
            0, 'Function type interned at index 0';
        is $emitter.intern-function-type(functype(resulttype(i32(), i32()), resulttype(i64()))),
                1, 'Different type interned at index 1';
        is $emitter.intern-function-type(functype(resulttype(i32(), i32()), resulttype(i32()))),
                2, 'Different type interned at index 2';
        is $emitter.intern-function-type(functype(resulttype(i32(), i32()), resulttype(i64()))),
                1, 'Interning works (1)';
        is $emitter.intern-function-type(functype(resulttype(i64(), i32()), resulttype(i64()))),
                0, 'Interning works (2)';

        my $buf = $emitter.assemble();
        pass 'Assembled module with some function types';
        is-wasmtime-output $buf, '';
    }

    subtest 'Function imports' => {
        my $emitter = Wasm::Emitter.new;
        my $typeidx = $emitter.intern-function-type:
                functype(resulttype(i32(), i32(), i32(), i32()), resulttype(i32()));
        is $emitter.import-function("wasi_unstable", "fd_write", $typeidx),
                0, 'First imported function got expected 0 index';
        is $emitter.import-function("wasi_unstable", "fd_read", $typeidx),
                1, 'Second imported function got expected 1 index';

        my $buf = $emitter.assemble();
        pass 'Assembled module with some function imports';
        is-wasmtime-output $buf, '';
    }

    subtest 'Declare a memory' => {
        my $emitter = Wasm::Emitter.new;
        is $emitter.add-memory(limitstype(0)), 0,
                'Expected index for added memory';

        my $buf = $emitter.assemble();
        pass 'Assembled module with some function imports';
        is-wasmtime-output $buf, '';
    }

    subtest 'Declare and export a memory' => {
        my $emitter = Wasm::Emitter.new;
        my $memory = $emitter.add-memory(limitstype(1));
        $emitter.export-memory("memory", $memory);

        my $buf = $emitter.assemble();
        pass 'Assembled module with some exported memory';
        is-wasmtime-output $buf, '';
    }

    subtest 'Declare data' => {
        my $emitter = Wasm::Emitter.new;
        $emitter.add-memory(limitstype(1));
        is $emitter.passive-data("hello world\n".encode('utf-8')), 0,
                'First (passive) data declaration at index zero';
        my $expression = Wasm::Emitter::Expression.new;
        $expression.i32-const(8);
        is $emitter.active-data("hello world\n".encode('utf-8'), $expression), 1,
                'Second (active) data declaration at index zero';

        my $buf = $emitter.assemble();
        pass 'Assembled module with data section';
        is-wasmtime-output $buf, '';
    }

    subtest 'Function declaration' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type(functype(resulttype(), resulttype(i32())));
        my $expression = Wasm::Emitter::Expression.new;
        $expression.i32-const(42);
        is $emitter.add-function(Wasm::Emitter::Function.new(:$type-index, :$expression)),
                0, 'Correct index for first added function';

        my $buf = $emitter.assemble();
        pass 'Assembled module with data section';
        is-wasmtime-output $buf, '';
    }
}
else {
    skip 'No wasmtime available to run test output; skipping';
}

done-testing;
