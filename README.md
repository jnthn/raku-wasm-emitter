# Wasm::Emitter

A Raku module to emit the [WebAssembly](https://webassembly.org/) binary
format.

## Example

This emits the "hello world" WebAssembly program using WASI (the WebAssembly
System Interface) to provide I/O functions. 

```raku
# Create an instance of the emitter, which can emit a module.
my $emitter = Wasm::Emitter.new;

# Import fd_write
my $fd-write-type = $emitter.function-type:
        functype(resulttype(i32(), i32(), i32(), i32()), resulttype(i32()));
my $fd-write-index = $emitter.import-function("wasi_unstable", "fd_write", $fd-write-type);

# Declare and export a memory.
$emitter.export-memory("memory", $emitter.memory(limitstype(1)));

# Write 'hello world\n' to memory at an offset of 8 bytes
my $offset-expression = Wasm::Emitter::Expression.new;
$offset-expression.i32-const(8);
$emitter.active-data("hello world\n".encode('utf-8'), $offset-expression);

# Generate code to call fd_write.
my $code = Wasm::Emitter::Expression.new;
given $code {
    # (i32.store (i32.const 0) (i32.const 8))
    .i32-const(0);
    .i32-const(8);
    .i32-store;
    # (i32.store (i32.const 4) (i32.const 12))
    .i32-const(4);
    .i32-const(12);
    .i32-store;
    # (call $fd_write
    #   (i32.const 1) ;; file_descriptor - 1 for stdout
    #   (i32.const 0) ;; *iovs - The pointer to the iov array, which is stored at memory location 0
    #   (i32.const 1) ;; iovs_len - We're printing 1 string stored in an iov - so one.
    #   (i32.const 20) ;; nwritten - A place in memory to store the number of bytes written
    # )
    .i32-const(1);
    .i32-const(0);
    .i32-const(1);
    .i32-const(20);
    .call($fd-write-index);
    # Drop return value
    .drop;
}

# Declare and export the start function.
my $start-type = $emitter.function-type: functype(resulttype(), resulttype());
my $start-func-index = $emitter.function: Wasm::Emitter::Function.new:
        :type-index($start-type), :expression($code);
$emitter.export-function('_start', $start-func-index);

# Assemble and write to a file, which can be run by, for example, wasmtime.
my $buf = $emitter.assemble();
spurt 'hello.wasm', $buf;
```

## API Documentation

Refer to the Pod documentation on the types and functions.

## Functionality

To the best of my knowledge, this covers all of the WebAssembly 2.0 specified
features except the vector instructions. None of the proposed specifications
are currently implemented (although some of them are liable to attract my
attention ahead of the vector instructions).

## Support policy

This is a module developed for personal interest. I'm sharing it in case it's
fun or useful to anybody else, not because I want yet another open source
project to maintain. PRs that include tests and are provided in an easy to
review form will likely be merged quite quickly, so long as no major flaws
are noticed. For anything needing more effort on my part, please don't expect
a quick response.
