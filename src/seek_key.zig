const std = @import("std");
const c = @import("c.zig");
const varint = @import("varint.zig");
const constants = @import("constants.zig");

pub const SEEK_ERROR = error {
    NOT_FOUND
};

pub fn seekKey(env: c.napi_env, buffer: []u8, start: u32, target: []u8) SEEK_ERROR!u32 {
    var tag = varint.decode(buffer, start) catch return error.NOT_FOUND;
    var typ = tag.res & constants.TAG_MASK;

    var target_length = target.len;
    var len = tag.res >> constants.TAG_SIZE;
    var i = tag.bytes;

    while(i < len) {
        var key_tag = varint.decode(buffer, start + i) catch return error.NOT_FOUND;
        i += key_tag.bytes;
        var key_len = key_tag.res >> constants.TAG_SIZE;
        var key_type = key_tag.res & constants.TAG_MASK;
        if (key_type == constants.STRING and target_length == key_len) {
            for (target) |u, j| {
                if (buffer[start + i + j] != u) {
                    break;
                }
                if (j == target_length - 1) {
                    return start + i + key_len;
                }                
            }
        }

        i += key_len;
        var value_tag = varint.decode(buffer, start + i) catch return error.NOT_FOUND;
        i += value_tag.bytes;
        var value_len = value_tag.res >> constants.TAG_SIZE;
        i += value_len;
    }

    return error.NOT_FOUND;
}

pub fn slice(env: c.napi_env, buffer: []u8, start: u32) SEEK_ERROR![]u8 {
    var tag = varint.decode(buffer, start) catch return error.NOT_FOUND;
    var new_start = start + tag.bytes;
    
    return buffer[new_start..new_start + (tag.res >> constants.TAG_SIZE)];
}