use v6.d;

#| Emitter for a binary Wasm module. An instance of this represents a module.
#| Make the various declarations, and then call C<assemble> to produce a
#| C<Buf> with the WebAssembly.
class Wasm::Emitter {

    #| Assemble the produced declarations into a final output.
    method assemble(--> Buf) {
        # Emit header.
        my Buf $output = Buf.new;
        my uint $pos = 0;
        for #`(magic) 0x00, 0x61, 0x73, 0x6D, #`(version) 0x01, 0x00, 0x00, 0x00 {
            $output.write-uint8($pos++, $_);
        }

        $output
    }
}
