use v6.d;
use Wasm::Emitter;
use Wasm::Emitter::Expression;
use Wasm::Emitter::Function;
use Wasm::Emitter::Types;
use Test;

sub has-wasmtime() {
    so qqx/wasmtime -h/
}

sub is-function-output(Buf $wasm, @args, $expected, :$function = 'test') {
    # Write WASM to a temporary file.
    my $temp-file = $*TMPDIR.add("raku-wasm-$*PID.wasm");
    spurt $temp-file, $wasm;
    LEAVE try unlink $temp-file;

    # Try running it.
    my $exitcode = -1;
    my $output = '';
    react {
        my $proc = Proc::Async.new('wasmtime', $temp-file, '--invoke' , $function, @args);
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
    $output .= trim;
    if $output ~~ $expected {
        pass "Correct output";
    }
    else {
        diag "Got $output.raku()";
        flunk "Correct output";
    }
}

sub test-nullary(Wasm::Emitter::Expression $expression, Wasm::Emitter::Types::ValueType $type, $expected) {
    my $emitter = Wasm::Emitter.new;
    my $type-index = $emitter.intern-function-type: functype(resulttype(), resulttype($type));
    my $func-index = $emitter.add-function: Wasm::Emitter::Function.new(:$type-index, :$expression);
    $emitter.export-function('test', $func-index);
    my $buf = $emitter.assemble();
    pass 'Assembled module';
    is-function-output $buf, [], $expected;
}

if has-wasmtime() {
    for i32(), 'i32-const', i64(), 'i64-const' -> $type, $op {
        subtest "$op" => {
            my $expression = Wasm::Emitter::Expression.new;
            $expression."$op"(12345);
            test-nullary $expression, $type, '12345';
        }
    }

    for f32(), 'f32-const', f64(), 'f64-const' -> $type, $op {
        subtest "$op" => {
            my $expression = Wasm::Emitter::Expression.new;
            $expression."$op"(12.45e0);
            test-nullary $expression, $type, '12.45';
        }
    }

    for 'f32-', 'f64-' -> $op-base {
        for 'eq', 0, 'ne', 1, 'lt', 0, 'le', 0, 'gt', 1, 'ge', 1 -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(10.9e0);
                $expression."{ $op-base }const"(5.2e0);
                $expression."$op-base$op"();
                test-nullary $expression, i32(), ~$expected;
            }
        }
    }

    subtest 'Locals and instructions (get/set/tee)' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :$expression);
        my $local-id-a = $function.declare-local(i32());
        my $local-id-b = $function.declare-local(i32());
        $expression.i32-const(99);
        $expression.local-set($local-id-a);
        $expression.local-get($local-id-a);
        $expression.local-tee($local-id-b);
        $expression.drop;
        $expression.local-get($local-id-b);
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [], '99';
    }
}
else {
    skip 'No wasmtime available to run test output; skipping';
}

done-testing;
