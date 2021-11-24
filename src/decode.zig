const std = @import("std");
const c = @import("c.zig");
const helpers = @import("helpers.zig");
const varint = @import("varint.zig");
const constants = @import("constants.zig");

const Decoders = struct {
    pub fn String(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        const end = start + len;
        var string: c.napi_value = undefined;
        if (c.napi_create_string_utf8(env, @ptrCast([*c]u8, source[start..end]), len, &string) != .napi_ok) {
            return helpers.throw(env, "Failed to decode string");
        }
        return string;
    }

    pub fn Buffer(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        const end = start + len;
        var buffer: c.napi_value = undefined;
        // TODO: do we a napi_finalize to clean up the underlying bytes, or not?
        if (c.napi_create_external_buffer(env, len, @ptrCast(*c_void, source[start..end]), null, null, &buffer) != .napi_ok) {
            return helpers.throw(env, "Failed to decode buffer");
        }
        return buffer;
    }

    pub fn Integer(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        const end = start + len;
        const i: i32 = std.mem.readIntSliceLittle(i32, source[start..end]);
        var integer: c.napi_value = undefined;
        if (c.napi_create_int32(env, i, &integer) != .napi_ok) {
            return helpers.throw(env, "Failed to decode integer");
        }
        return integer;
    }

    pub fn Double(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        if (len != 8) {
            return helpers.throw(env, "Bad length for decoding a double");
        }
        var end = start + len;
        var array: [8]u8 = undefined;
        std.mem.copy(u8, &array, source[start..end]);
        var double = std.mem.bytesAsValue(f64, &array);
        var number: c.napi_value = undefined;
        if (c.napi_create_double(env, double.*, &number) != .napi_ok) {
            return helpers.throw(env, "Failed to decode double");
        }
        return number;
    }

    pub fn Array(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        var array: c.napi_value = undefined;
        if (c.napi_create_array(env, &array) != .napi_ok) {
            return helpers.throw(env, "Failed to create decodable array");
        }
        const end = start + len;
        var position: u32 = start;
        while (position < end) {
            const elemTag = varint.decode(source, position) catch return null;
            const elemType = @intCast(u8, elemTag.res & constants.TAG_MASK);
            const elemLen = elemTag.res >> constants.TAG_SIZE;
            position += elemTag.bytes;
            var elem = Decoders.Any(env, elemType, source, position, elemLen) catch return null;
            helpers.arrayPush(env, array, elem) catch return null;
            position += elemLen;
        }
        return array;
    }

    pub fn Object(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        var object: c.napi_value = undefined;
        if (c.napi_create_object(env, &object) != .napi_ok) {
            return helpers.throw(env, "Failed to create decodable object");
        }
        const end = start + len;
        var position: u32 = start;
        while (position < end) {
            const keyTag = varint.decode(source, position) catch return null;
            const keyType = @intCast(u8, keyTag.res & constants.TAG_MASK);
            const keyLen = keyTag.res >> constants.TAG_SIZE;
            position += keyTag.bytes;
            var key = Decoders.Any(env, keyType, source, position, keyLen) catch return null;
            position += keyLen;
            const valueTag = varint.decode(source, position) catch return null;
            const valueType = @intCast(u8, valueTag.res & constants.TAG_MASK);
            const valueLen = valueTag.res >> constants.TAG_SIZE;
            position += valueTag.bytes;
            var value = Decoders.Any(env, valueType, source, position, valueLen) catch return null;
            if (c.napi_set_property(env, object, key, value) != .napi_ok) {
                return helpers.throw(env, "Failed to set property");
            }
            position += valueLen;
        }
        return object;
    }

    pub fn BoolNull(env: c.napi_env, source: []u8, start: u32, len: u32) !c.napi_value {
        var result: c.napi_value = undefined;
        if (len == 0) {
            if (c.napi_get_null(env, &result) != .napi_ok) {
                return helpers.throw(env, "Failed to decode null");
            }
            return result;
        }

        if (len != 1) {
            return helpers.throw(env, "Bad length for decoding a bool or null");
        }
        if (source[start] == 0) {
            if (c.napi_get_boolean(env, false, &result) != .napi_ok) {
                return helpers.throw(env, "Failed to decode boolean false");
            }
        } else if (source[start] == 1) {
            if (c.napi_get_boolean(env, true, &result) != .napi_ok) {
                return helpers.throw(env, "Failed to decode boolean true");
            }
        } else if (source[start] == 2) {
            if (c.napi_get_undefined(env, &result) != .napi_ok) {
                return helpers.throw(env, "Failed to decode undefined");
            }
        }
        return result;
    }

    pub fn Any(env: c.napi_env, _type: u8, buffer: []u8, start: u32, len: u32) !c.napi_value {
        return switch (_type) {
            constants.STRING => Decoders.String(env, buffer, start, len),
            constants.BUFFER => Decoders.Buffer(env, buffer, start, len),
            constants.INT => Decoders.Integer(env, buffer, start, len),
            constants.DOUBLE => Decoders.Double(env, buffer, start, len),
            constants.ARRAY => Decoders.Array(env, buffer, start, len),
            constants.OBJECT => Decoders.Object(env, buffer, start, len),
            constants.BOOLNULL => Decoders.BoolNull(env, buffer, start, len),
            else => null,
        };
    }
};

pub fn decode(env: c.napi_env, buffer: []u8, start: u32) !c.napi_value {
    const tag = varint.decode(buffer, start) catch return null;
    const _type = @intCast(u8, tag.res & constants.TAG_MASK);
    const len = tag.res >> constants.TAG_SIZE;
    return Decoders.Any(env, _type, buffer, start + tag.bytes, len) catch return null;
}
