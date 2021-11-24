const std = @import("std");

const VarIntError = error{
    DecodeFailed,
};

pub fn encodingLength(value: u32) u8 {
    if (value < comptime std.math.pow(u64, 2, 7)) return 1;
    if (value < comptime std.math.pow(u64, 2, 14)) return 2;
    if (value < comptime std.math.pow(u64, 2, 21)) return 3;
    if (value < comptime std.math.pow(u64, 2, 28)) return 4;
    if (value < comptime std.math.pow(u64, 2, 35)) return 5;
    if (value < comptime std.math.pow(u64, 2, 42)) return 6;
    if (value < comptime std.math.pow(u64, 2, 49)) return 7;
    if (value < comptime std.math.pow(u64, 2, 56)) return 8;
    if (value < comptime std.math.pow(u64, 2, 63)) return 9;
    return 10;
}

const MSB = 0x80;
const REST = 0x7F;
const MSBALL = comptime ~@as(u32, REST);
const INT = comptime std.math.pow(u32, 2, 31);

pub fn encode(num: u32, out: []u8, offset: u32) u32 {
    var _num: u32 = num;
    var _offset: u32 = offset;
    var oldOffset: u32 = _offset;

    while (_num >= INT) {
        out[_offset] = @intCast(u8, (_num & 0xFF) | MSB);
        _offset += 1;
        _num /= 128;
    }
    while (_num & MSBALL > 0) {
        out[_offset] = @intCast(u8, (_num & 0xFF) | MSB);
        _offset += 1;
        _num = _num >> 7;
    }
    out[_offset] = @intCast(u8, _num | 0);
    var bytes = _offset - oldOffset + 1;
    return bytes;
}

pub const Decoded = struct {
    res: u32,
    bytes: u32,
};

pub fn decode(in: []u8, offset: u32) VarIntError!Decoded {
    var res: u32 = 0;
    var shift: u5 = 0;
    var counter: u32 = offset;
    const len = in.len;
    var byte: u32 = undefined;

    while (true)  {
        if (counter >= len) return VarIntError.DecodeFailed;
        byte = @intCast(u32, in[counter]);
        counter += 1;
        res += if (shift < 28)
            ((byte & REST) << shift)
        else
            ((byte & REST) * std.math.pow(u32, 2, shift));
        shift += 7;
        if (byte < MSB) break;
    }

    return Decoded{ .bytes = counter - offset, .res = res };
}
