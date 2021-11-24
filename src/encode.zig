const std = @import("std");
const c = @import("c.zig");
const helpers = @import("helpers.zig");
const varint = @import("varint.zig");
const constants = @import("constants.zig");

fn getType(env: c.napi_env, value: c.napi_value) u8 {
    if (helpers.isTypeof(env, value, c.napi_valuetype.napi_string)) return constants.STRING;

    if (helpers.instanceOfDate(env, value) catch false) return constants.STRING;

    var isBuffer: bool = undefined;
    if (c.napi_is_buffer(env, value, &isBuffer) == .napi_ok) {
        if (isBuffer) return constants.BUFFER;
    }

    if (helpers.callBoolMethod(env, "Number", "isInteger", value) catch false) {
        var num: i32 = undefined;
        if (c.napi_get_value_int32(env, value, &num) == .napi_ok) {
            if (std.math.absInt(num) catch 0 < 4294967296) return constants.INT;
        }
    }

    if (helpers.isTypeof(env, value, c.napi_valuetype.napi_number) and
        helpers.callBoolMethod(env, "Number", "isFinite", value) catch false)
    {
        return constants.DOUBLE;
    }

    var isArray: bool = undefined;
    if (c.napi_is_array(env, value, &isArray) == .napi_ok) {
        if (isArray) return constants.ARRAY;
    }

    if ((helpers.isTruthy(env, value) catch false) and
        helpers.isTypeof(env, value, c.napi_valuetype.napi_object)) return constants.OBJECT;

    if (helpers.isTypeof(env, value, c.napi_valuetype.napi_boolean)) return constants.BOOLNULL;

    if (helpers.isNull(env, value) catch false) return constants.BOOLNULL;
    if (helpers.isUndefined(env, value) catch false) return constants.BOOLNULL;

    return constants.RESERVED;
}

const Encoders = struct {
    pub fn String(env: c.napi_env, string: c.napi_value, dest: []u8, start: u32) !u32 {
        var bytes: usize = 0;
        if (c.napi_get_value_string_utf8(env, string, @ptrCast([*c]u8, dest[start..]), dest.len, &bytes) != .napi_ok) {
            return helpers.throw(env, "Failed to encode string");
        }
        return @intCast(u32, bytes);
    }

    pub fn Buffer(env: c.napi_env, buffer: c.napi_value, dest: []u8, start: u32) !u32 {
        var bytes: usize = 0;
        var slice = helpers.slice_from_value(env, buffer, "buffer") catch return 0;
        const end = start + slice.len;
        std.mem.copy(u8, dest[start..end], slice[0..slice.len]);
        return @intCast(u32, slice.len);
    }

    pub fn Integer(env: c.napi_env, int: c.napi_value, dest: []u8, start: u32) !u32 {
        var i: i32 = undefined;
        if (c.napi_get_value_int32(env, int, &i) != .napi_ok) {
            return helpers.throw(env, "Failed to encode integer");
        }
        var slice = std.mem.asBytes(&i);
        if (slice.len > dest.len) {
            return helpers.throw(env, "Failed to encode integer as bytes");
        }
        const end = start + slice.len;
        std.mem.copy(u8, dest[start..end], slice[0..slice.len]);
        return 4;
    }

    pub fn Double(env: c.napi_env, double: c.napi_value, dest: []u8, start: u32) !u32 {
        var x: f64 = undefined;
        if (c.napi_get_value_double(env, double, &x) != .napi_ok) {
            return helpers.throw(env, "Failed to encode double");
        }
        var slice = std.mem.asBytes(&x);
        if (slice.len > dest.len) {
            return helpers.throw(env, "Failed to encode double as bytes");
        }
        const end = start + slice.len;
        std.mem.copy(u8, dest[start..end], slice[0..slice.len]);
        return 8;
    }

    pub fn Array(env: c.napi_env, array: c.napi_value, dest: []u8, start: u32) !u32 {
        var length: u32 = undefined;
        if (c.napi_get_array_length(env, array, &length) != .napi_ok) {
            return helpers.throw(env, "Failed to get array length");
        }
        var i: u32 = 0;
        var position: u32 = start;
        while (i < length) : (i += 1) {
            var elem: c.napi_value = undefined;
            if (c.napi_get_element(env, array, i, &elem) != .napi_ok) {
                return helpers.throw(env, "Failed to get array element");
            }
            position += encode(env, elem, dest, position) catch return 0;
        }
        return position - start;
    }

    pub fn Object(env: c.napi_env, object: c.napi_value, dest: []u8, start: u32) !u32 {
        var keys: c.napi_value = undefined;
        if (c.napi_get_property_names(env, object, &keys) != .napi_ok) {
            return helpers.throw(env, "Failed to get object keys");
        }
        var length: u32 = undefined;
        if (c.napi_get_array_length(env, keys, &length) != .napi_ok) {
            return helpers.throw(env, "Failed to get object keys length");
        }
        var i: u32 = 0;
        var position: u32 = start;
        while (i < length) : (i += 1) {
            var key: c.napi_value = undefined;
            if (c.napi_get_element(env, keys, i, &key) != .napi_ok) {
                return helpers.throw(env, "Failed to get object key");
            }
            position += encode(env, key, dest, position) catch return 0;
            var value: c.napi_value = undefined;
            if (c.napi_get_property(env, object, key, &value) != .napi_ok) {
                return helpers.throw(env, "Failed to get object property");
            }
            position += encode(env, value, dest, position) catch return 0;
        }
        return position - start;
    }

    pub fn Boolnull(env: c.napi_env, boolnull: c.napi_value, dest: []u8, start: u32) !u32 {
        if (helpers.isNull(env, boolnull) catch false) {
            return 0;
        }
        if (helpers.isUndefined(env, boolnull) catch false) {
            dest[start] = 2;
            return 1;
        }
        var result: bool = undefined;
        if (c.napi_get_value_bool(env, boolnull, &result) != .napi_ok) {
            return helpers.throw(env, "Failed to get boolean value");
        }
        dest[start] = if (result) 1 else 0;
        return 1;
    }

    pub fn Any(env: c.napi_env, _type: u8, value: c.napi_value, buffer: []u8, start: u32) u32 {
        const len = switch (_type) {
            constants.INT => Encoders.Integer(env, value, buffer, start) catch 0,
            constants.BUFFER => Encoders.Buffer(env, value, buffer, start) catch 0,
            constants.STRING => Encoders.String(env, value, buffer, start) catch 0,
            constants.DOUBLE => Encoders.Double(env, value, buffer, start) catch 0,
            constants.ARRAY => Encoders.Array(env, value, buffer, start) catch 0,
            constants.OBJECT => Encoders.Object(env, value, buffer, start) catch 0,
            constants.BOOLNULL => Encoders.Boolnull(env, value, buffer, start) catch 0,
            else => 0,
        };
        return len;
    }
};

const EncodingLengthers = struct {
    pub fn String(env: c.napi_env, string: c.napi_value) !u32 {
        return helpers.bufferByteLength(env, string);
    }

    pub fn Buffer(env: c.napi_env, buffer: c.napi_value) !u32 {
        var length: c.napi_value = undefined;
        if (c.napi_get_named_property(env, buffer, "length", &length) != .napi_ok) {
            return helpers.throw(env, "Failed to get buffer.length");
        }

        var result: u32 = undefined;
        if (c.napi_get_value_uint32(env, length, &result) != .napi_ok) {
            return helpers.throw(env, "Failed to get the u32 value of buffer.length");
        }
        return result;
    }

    pub const Integer = 4;

    pub const Double = 8;

    pub fn Array(env: c.napi_env, array: c.napi_value) !u32 {
        var bytes: u32 = 0;
        var length: u32 = undefined;
        if (c.napi_get_array_length(env, array, &length) != .napi_ok) {
            return helpers.throw(env, "Failed to get array length");
        }
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            var elem: c.napi_value = undefined;
            if (c.napi_get_element(env, array, i, &elem) != .napi_ok) {
                return helpers.throw(env, "Failed to get array element");
            }
            bytes += encodingLength(env, elem) catch 0;
        }
        return bytes;
    }

    pub fn Object(env: c.napi_env, object: c.napi_value) !u32 {
        var bytes: u32 = 0;
        var keys: c.napi_value = undefined;
        if (c.napi_get_property_names(env, object, &keys) != .napi_ok) {
            return helpers.throw(env, "Failed to get object keys");
        }
        var length: u32 = undefined;
        if (c.napi_get_array_length(env, keys, &length) != .napi_ok) {
            return helpers.throw(env, "Failed to get object keys length");
        }
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            var key: c.napi_value = undefined;
            if (c.napi_get_element(env, keys, i, &key) != .napi_ok) {
                return helpers.throw(env, "Failed to get object key");
            }
            bytes += encodingLength(env, key) catch 0;
            var value: c.napi_value = undefined;
            if (c.napi_get_property(env, object, key, &value) != .napi_ok) {
                return helpers.throw(env, "Failed to get object property");
            }
            bytes += encodingLength(env, value) catch 0;
        }
        return bytes;
    }

    pub fn Boolnull(env: c.napi_env, value: c.napi_value) !u32 {
        if (helpers.isNull(env, value) catch false) return 0;
        return 1;
    }

    pub fn Any(env: c.napi_env, _type: u8, value: c.napi_value) u32 {
        const len = switch (_type) {
            constants.STRING => EncodingLengthers.String(env, value) catch 0,
            constants.BUFFER => EncodingLengthers.Buffer(env, value) catch 0,
            constants.INT => EncodingLengthers.Integer,
            constants.DOUBLE => EncodingLengthers.Double,
            constants.ARRAY => EncodingLengthers.Array(env, value) catch 0,
            constants.OBJECT => EncodingLengthers.Object(env, value) catch 0,
            constants.BOOLNULL => EncodingLengthers.Boolnull(env, value) catch 0,
            else => 0,
        };
        return len;
    }
};

pub fn encodingLength(env: c.napi_env, value: c.napi_value) !u32 {
    var _type = getType(env, value);
    const len = EncodingLengthers.Any(env, _type, value);
    return len + varint.encodingLength(len << constants.TAG_SIZE);
}

pub fn encode(env: c.napi_env, inputJS: c.napi_value, dest: []u8, start: u32) !u32 {
    var _type = getType(env, inputJS);
    if (_type >= constants.RESERVED) {
        helpers.throw(env, "unknown type") catch return 0;
    }
    var len = EncodingLengthers.Any(env, _type, inputJS);
    const bytes = varint.encode((len << constants.TAG_SIZE) | _type, dest, start);
    const encodedLen = Encoders.Any(env, _type, inputJS, dest, start + bytes);
    return encodedLen + bytes;
}
