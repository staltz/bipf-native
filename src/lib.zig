const std = @import("std");
const assert = std.debug.assert;
const c = @import("c.zig");
const helpers = @import("helpers.zig");
const enc = @import("encode.zig");
const dec = @import("decode.zig");

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    helpers.register_function(env, exports, "encodingLength", encodingLength) catch return null;
    helpers.register_function(env, exports, "encode", encode) catch return null;
    helpers.register_function(env, exports, "decode", decode) catch return null;
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
