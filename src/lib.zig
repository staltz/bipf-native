const std = @import("std");
const assert = std.debug.assert;
const c = @import("c.zig");
const helpers = @import("helpers.zig");
const enc = @import("encode.zig");
const dec = @import("decode.zig");
const seek_key = @import("seek_key.zig");
const seek_path = @import("seek_path.zig");

var alloc = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &alloc.allocator;

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    helpers.register_function(env, exports, "encodingLength", encodingLength) catch return null;
    helpers.register_function(env, exports, "encode", encode) catch return null;
    helpers.register_function(env, exports, "decode", decode) catch return null;
    helpers.register_function(env, exports, "seekKey", seekKey) catch return null;
    helpers.register_function(env, exports, "allocAndEncode", allocAndEncode) catch return null;
    helpers.register_function(env, exports, "slice", slice) catch return null;
    helpers.register_function(env, exports, "seekPath", seekPath) catch return null;
    return exports;
}

fn encodingLength(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 1;
    var argv: [1]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }

    var input = if (argc == 1) argv[0] else helpers.getUndefined(env) catch return null;
    const result = enc.encodingLength(env, input) catch return null;
    return helpers.u32ToJS(env, result) catch return null;
}

fn encode(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 4;
    var argv: [4]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 2) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }

    var inputJS = argv[0];

    var buffer = helpers.slice_from_value(env, argv[1], "buffer") catch return null;

    var start: u32 = undefined;
    if (argc >= 3) {
        if (c.napi_get_value_uint32(env, argv[2], &start) != .napi_ok) {
            helpers.throw(env, "Failed to get start") catch return null;
        }
    } else {
        start = 0;
    }

    var total = enc.encode(env, inputJS, buffer, start) catch return null;

    var totalJS: c.napi_value = undefined;
    if (c.napi_create_uint32(env, @intCast(u32, total), &totalJS) != .napi_ok) {
        helpers.throw(env, "Failed to create total") catch return null;
    }
    return totalJS;
}

fn decode(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 2;
    var argv: [2]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 1) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }

    var buffer = helpers.slice_from_value(env, argv[0], "buffer") catch return null;

    var start: u32 = undefined;
    if (argc >= 2) {
        if (c.napi_get_value_uint32(env, argv[1], &start) != .napi_ok) {
            helpers.throw(env, "Failed to get start") catch return null;
        }
    } else {
        start = 0;
    }

    return dec.decode(env, buffer, start) catch return null;
}

fn allocAndEncode(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 1;
    var argv: [1]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 1) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }

    var inputJS = argv[0];

    const len = enc.encodingLength(env, inputJS) catch 0;

    var dest = allocator.alloc(u8, len) catch return null;
    defer allocator.free(dest);

    var written = enc.encode(env, inputJS, dest, 0) catch 0;
    return helpers.create_buffer(env, dest, "could not create buffer") catch return null;
}

fn seekKey(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 3;
    var argv: [3]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 3) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }

    var buffer = helpers.slice_from_value(env, argv[0], "1st arg") catch return null;
    var start_i: i32 = undefined;
    if (c.napi_get_value_int32(env, argv[1], &start_i) != .napi_ok) {
        helpers.throw(env, "Failed to get start") catch return null;
    }

    if (start_i == -1) {
        return helpers.i32ToJS(env, -1) catch return null;
    }

    var key: []u8 = undefined;
    if (helpers.isTypeof(env, argv[2], c.napi_valuetype.napi_string)) {
        // TODO document / modify bound
        var bytes: usize = undefined;
        var len: usize = 1024;
        key = allocator.alloc(u8, len) catch return null;
        if (c.napi_get_value_string_utf8(env, argv[2], @ptrCast([*c]u8, key), len, &bytes) != .napi_ok) {
            helpers.throw(env, "3rd arg is not a string") catch return null;
        }
        key = key[0..bytes];
    } else {
        key = helpers.slice_from_value(env, argv[2], "3rd arg") catch return null;
    }
    defer allocator.free(key);
    if (seek_key.seekKey(env, buffer, @intCast(u32, start_i), key)) |result| {
        return helpers.u32ToJS(env, result) catch return null;
    } else |err| switch(err) {
        error.NOT_FOUND => return helpers.i32ToJS(env, -1) catch return null
    }
}

fn slice(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 2;
    var argv: [2]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 2) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }
    var buffer = helpers.slice_from_value(env, argv[0], "1st arg") catch return null;
    var start: u32 = undefined;
    if (c.napi_get_value_uint32(env, argv[1], &start) != .napi_ok) {
        helpers.throw(env, "Failed to get start") catch return null;
    }

    var res = seek_key.slice(env, buffer, start) catch return null;
    return helpers.create_buffer(env, res, "could not create buffer")catch return null;
}


fn seekPath(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    var argc: usize = 4;
    var argv: [4]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &argv, null, null) != .napi_ok) {
        helpers.throw(env, "Failed to get args") catch return null;
    }
    if (argc < 3) {
        helpers.throw(env, "Not enough arguments") catch return null;
    }

    var buffer = helpers.slice_from_value(env, argv[0], "1st arg") catch return null;

    var start_i: i32 = undefined;
    if (c.napi_get_value_int32(env, argv[1], &start_i) != .napi_ok) {
        helpers.throw(env, "Failed to get start") catch return null;
    }

    if (start_i == -1) {
        return helpers.i32ToJS(env, -1) catch return null;
    }

    var target = helpers.slice_from_value(env, argv[2], "3rd arg") catch return null;

    var target_start: u32 = 0;
    if (argc >= 4) {
        if (c.napi_get_value_uint32(env, argv[3], &target_start) != .napi_ok) {
            helpers.throw(env, "Failed to get target_start") catch return null;            
        }
    }

    if (seek_path.seekPath(env, buffer, @intCast(u32, start_i), target, target_start)) |res| {
        return helpers.u32ToJS(env, res) catch return null;
    } else |err| switch(err) {
        error.NOT_FOUND => return helpers.i32ToJS(env, -1) catch return null,
        error.NOT_AN_ARRAY => return helpers.throw(env, "path must be encoded array") catch return null,
        error.NOT_STRING_OR_BUFFER => return helpers.throw(env, "path must be encoded array of strings") catch return null
    }
}