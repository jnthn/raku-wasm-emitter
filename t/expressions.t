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

    for 'i32-', 'i64-' -> $op-base {
        for 'eq', 0, 'ne', 1, 'lt-s', 0, 'lt-u', 1, 'le-s', 0, 'le-u', 1,
                'gt-s', 1, 'gt-u', 0, 'ge-s', 1, 'ge-u', 0 -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(10);
                $expression."{ $op-base }const"(-5);
                $expression."$op-base$op"();
                test-nullary $expression, i32(), ~$expected;
            }
        }
        for 0, 1, 1, 0 -> $value, $expected {
            subtest "{$op-base}eqz" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"($value);
                $expression."{$op-base}eqz"();
                test-nullary $expression, i32(), ~$expected;
            }
        }
    }

    for 'clz', 5, 'ctz', 6, 'popcnt', 7 -> $op, $expected {
        subtest "i32-$op" => {
            my $expression = Wasm::Emitter::Expression.new;
            $expression."i32-const"(0b0000_0100_0011_0010_0000_0011_0100_0000);
            $expression."i32-$op"();
            test-nullary $expression, i32(), $expected;
        }
        subtest "i64-$op" => {
            my $expression = Wasm::Emitter::Expression.new;
            $expression."i64-const"(0b0000_0100_0000_0000_0011_0000_0010_0000_0000_0000_0000_0000_0011_0000_0100_0000);
            $expression."i64-$op"();
            test-nullary $expression, i64(), $expected;
        }
    }

    for i32(), 'i32-', i64(), 'i64-' -> $type, $op-base {
        for 'add', 20, 'sub', 10, 'mul', 75, 'div-s', 3, 'div-u', 3,
                'rem-s', 0, 'rem-u', 0 -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(15);
                $expression."{ $op-base }const"(5);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
            }
        }
    }

    for i32(), 'i32-', i64(), 'i64-' -> $type, $op-base {
        for 'and', 0b0010, 'or', 0b1110, 'xor', 0b1100 -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(0b1010);
                $expression."{ $op-base }const"(0b0110);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
            }
        }
    }

    for i32(), 'i32-', i64(), 'i64-' -> $type, $op-base {
        for 'shl', 0b10101101000, 'shr-s', 0b10101, 'shr-u', 0b10101 -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(0b10101101);
                $expression."{ $op-base }const"(3);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
            }
        }
    }

    for i32(), 'i32-', i64(), 'i64-' -> $type, $op-base {
        for 'rotl', 0b1101_1000, 'rotr', 0b0011_0110  -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(0b0110_1100);
                $expression."{ $op-base }const"(1);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
            }
        }
    }

    for f32(), 'f32-', f64(), 'f64-' -> $type, $op-base {
        for 'abs', '30.25', 'neg', '-30.25', 'ceil', '31', 'floor', '30',
                'trunc', '30', 'nearest', '30', 'sqrt', '5.5' -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(30.25e0);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
            }
        }
    }

    for f32(), 'f32-', f64(), 'f64-' -> $type, $op-base {
        for 'add', '7', 'sub', '14', 'mul', '-36.75', 'div', '-3',
                'min', '-3.5', 'max', '10.5', 'copysign', '-10.5' -> $op, $expected {
            subtest "$op-base$op" => {
                my $expression = Wasm::Emitter::Expression.new;
                $expression."{ $op-base }const"(10.5e0);
                $expression."{ $op-base }const"(-3.5e0);
                $expression."$op-base$op"();
                test-nullary $expression, $type, $expected;
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

    subtest 'Parameters' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(i32(), i32()), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :2parameters, :$expression);
        my $local-id = $function.declare-local(i32());
        is $local-id, 2, 'Locals numbered from parameter count';
        $expression.local-get(0);
        $expression.local-get(1);
        $expression.i32-sub();
        $expression.local-set($local-id);
        $expression.local-get($local-id);
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [49, 7], '42';
    }

    subtest 'nop, return, and unreachable' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :$expression);
        $expression.nop();
        $expression.i32-const(101);
        $expression.nop();
        $expression.return();
        $expression.unreachable();
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [], '101';
    }

    subtest 'if' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(i32()), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :1parameters, :$expression);
        $expression.local-get(0);
        $expression.if: {
            $expression.i32-const(99);
            $expression.return;
        }
        $expression.i32-const(100);
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [1], '99';
        is-function-output $buf, [0], '100';
    }

    subtest 'if' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(i32()), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :1parameters, :$expression);
        $expression.local-get(0);
        $expression.if: :blocktype(i32()),
                {
                    $expression.i32-const(25);
                },
                {
                    $expression.i32-const(75);
                };
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [1], '25';
        is-function-output $buf, [0], '75';
    }

    subtest 'block/br' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index, :$expression);
        $expression.block: :blocktype(i32()), {
            $expression.i32-const(66);
            $expression.br(0);
            $expression.drop();
            $expression.i32-const(69);
        }
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [], '66';
    }

    subtest 'block/br_if' => {
        my $emitter = Wasm::Emitter.new;
        my $type-index = $emitter.intern-function-type: functype(resulttype(i32()), resulttype(i32()));
        my $expression = Wasm::Emitter::Expression.new;
        my $function = Wasm::Emitter::Function.new(:$type-index :1parameters, :$expression);
        $expression.block: :blocktype(i32()), {
            $expression.i32-const(66);
            $expression.local-get(0);
            $expression.br-if(0);
            $expression.drop();
            $expression.i32-const(69);
        }
        $emitter.export-function('test', $emitter.add-function($function));
        my $buf = $emitter.assemble();
        pass 'Assembled module';
        is-function-output $buf, [1], '66';
        is-function-output $buf, [0], '69';
    }
}
else {
    skip 'No wasmtime available to run test output; skipping';
}

done-testing;
