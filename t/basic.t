use v6.d;
use Wasm::Emitter;
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
}
else {
    skip 'No wasmtime available to run test output; skipping';
}

done-testing;
