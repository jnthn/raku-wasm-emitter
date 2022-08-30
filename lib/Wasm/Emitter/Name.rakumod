use v6.d;
use LEB128;

#| Emit a string as a WebAssembly name.
sub emit-name(Buf $into, uint $offset, Str $name --> uint) is export {
    my Blob $encoded = $name.encode('UTF-8');
    my int $pos = $offset;
    $pos += encode-leb128-unsigned($encoded.elems, $into, $pos);
    $into.append($encoded);
    $pos += $encoded.elems;
    $pos - $offset
}
