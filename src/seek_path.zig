const std = @import("std");
const c = @import("c.zig");
const varint = @import("varint.zig");
const constants = @import("constants.zig");
const seek_key = @import("seek_key.zig");

pub const SEEK_PATH_ERROR = error {
    NOT_FOUND,
    NOT_AN_ARRAY,
    NOT_STRING_OR_BUFFER
};

pub fn seekPath(env: c.napi_env, buffer: []u8, start: u32, target: []u8, target_start: u32) SEEK_PATH_ERROR!u32 {
    var tag = varint.decode(target, target_start) catch return error.NOT_FOUND;
    var _type = @intCast(u8, tag.res & constants.TAG_MASK);
    const len = tag.res >> constants.TAG_SIZE;

    if (_type != constants.ARRAY) {
        return error.NOT_AN_ARRAY;
    }

    var position = target_start + tag.bytes;
    var res = start;

    while(position < len) {
        tag = varint.decode(target, position) catch return error.NOT_FOUND;
        _type = @intCast(u8, tag.res & constants.TAG_MASK);
        if (_type >= constants.INT) {
            return error.NOT_STRING_OR_BUFFER;
        }
        var key_len = tag.res >> constants.TAG_SIZE;
        position += tag.bytes;

        if (seek_key.seekKey(env, buffer, res, target[position..position + key_len])) |seeked| {
            res = seeked;
            position += key_len;
        } else |err| switch(err) {
            seek_key.SEEK_ERROR.NOT_FOUND => return error.NOT_FOUND
        }
    }
    return res;
}