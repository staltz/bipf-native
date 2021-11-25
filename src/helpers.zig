const translate = @import("translate.zig");
const std = @import("std");
const c = @import("c.zig");

pub const register_function = translate.register_function;
pub const throw = translate.throw;
pub const slice_from_value = translate.slice_from_value;
pub const create_buffer = translate.create_buffer;

pub fn create_string(env: c.napi_env, value: [:0]const u8) !c.napi_value {
    var result: c.napi_value = undefined;
    if (c.napi_create_string_utf8(env, value, value.len, &result) != .napi_ok) {
        return translate.throw(env, "Failed to create string");
    }

    return result;
}

pub fn console_log(env: c.napi_env, message: c.napi_value) !void {
    var global: c.napi_value = undefined;
    if (c.napi_get_global(env, &global) != .napi_ok) {
        return translate.throw(env, "Failed to get global object");
    }

    var napi_console: c.napi_value = undefined;
    if (c.napi_get_named_property(env, global, "console", &napi_console) != .napi_ok) {
        return translate.throw(env, "Failed to get the console object");
    }

    var napi_log: c.napi_value = undefined;
    if (c.napi_get_named_property(env, napi_console, "log", &napi_log) != .napi_ok) {
        return translate.throw(env, "Failed to get the log function");
    }

    var returned: c.napi_value = undefined;
    if (c.napi_call_function(env, napi_console, napi_log, 1, &message, &returned) != .napi_ok) {
        return translate.throw(env, "Failed to call the log function");
    }
}

pub fn isTypeof(env: c.napi_env, value: c.napi_value, expected: c.napi_valuetype) bool {
    var actual: c.napi_valuetype = undefined;
    if (c.napi_typeof(env, value, &actual) == .napi_ok) {
        return actual == expected;
    }
    return false;
}

pub fn instanceOfDate(env: c.napi_env, value: c.napi_value) !bool {
    var global: c.napi_value = undefined;
    if (c.napi_get_global(env, &global) != .napi_ok) {
        return translate.throw(env, "Failed to get global object");
    }

    var date: c.napi_value = undefined;
    if (c.napi_get_named_property(env, global, "Date", &date) != .napi_ok) {
        return translate.throw(env, "Failed to get the Date constructor");
    }

    var result: bool = undefined;
    if (c.napi_instanceof(env, value, date, &result) != .napi_ok) {
        return translate.throw(env, "Failed to execute instanceof");
    }
    return result;
}

pub fn callBoolMethod(env: c.napi_env, comptime objectName: [:0]const u8, comptime methodName: [:0]const u8, arg: c.napi_value) !bool {
    var global: c.napi_value = undefined;
    if (c.napi_get_global(env, &global) != .napi_ok) {
        return translate.throw(env, "Failed to get global object");
    }

    var object: c.napi_value = undefined;
    if (c.napi_get_named_property(env, global, objectName, &object) != .napi_ok) {
        return translate.throw(env, "Failed to get the object");
    }

    var method: c.napi_value = undefined;
    if (c.napi_get_named_property(env, object, methodName, &method) != .napi_ok) {
        return translate.throw(env, "Failed to get the method on the object");
    }

    var returned: c.napi_value = undefined;
    if (c.napi_call_function(env, object, method, 1, &arg, &returned) != .napi_ok) {
        return translate.throw(env, "Failed to call the method on the object");
    }

    var result: bool = undefined;
    if (c.napi_get_value_bool(env, returned, &result) != .napi_ok) {
        return translate.throw(env, "Failed to get the return value");
    }

    return result;
}

pub fn arrayPush(env: c.napi_env, arr: c.napi_value, item: c.napi_value) !void {
    var length: u32 = undefined;
    if (c.napi_get_array_length(env, arr, &length) != .napi_ok) {
        return translate.throw(env, "Failed to get array length");
    }

    if (c.napi_set_element(env, arr, length, item) != .napi_ok) {
        return translate.throw(env, "Failed to set array element");
    }
}

pub fn isTruthy(env: c.napi_env, value: c.napi_value) !bool {
    var global: c.napi_value = undefined;
    if (c.napi_get_global(env, &global) != .napi_ok) {
        return translate.throw(env, "Failed to get global object");
    }

    var booleanFn: c.napi_value = undefined;
    if (c.napi_get_named_property(env, global, "Boolean", &booleanFn) != .napi_ok) {
        return translate.throw(env, "Failed to get the Boolean constructor");
    }

    var returned: c.napi_value = undefined;
    if (c.napi_call_function(env, global, booleanFn, 1, &value, &returned) != .napi_ok) {
        return translate.throw(env, "Failed to call the Boolean constructor");
    }

    var result: bool = undefined;
    if (c.napi_get_value_bool(env, returned, &result) != .napi_ok) {
        return translate.throw(env, "Failed to get the return value of Boolean");
    }

    return result;
}

pub fn isNull(env: c.napi_env, value: c.napi_value) !bool {
    var nullJS: c.napi_value = undefined;
    if (c.napi_get_null(env, &nullJS) != .napi_ok) {
        return translate.throw(env, "Failed to get the null value");
    }

    var result: bool = undefined;
    if (c.napi_strict_equals(env, value, nullJS, &result) != .napi_ok) {
        return translate.throw(env, "Failed to compare the value to null");
    }
    return result;
}

pub fn isUndefined(env: c.napi_env, value: c.napi_value) !bool {
    var undefinedJS = try getUndefined(env);

    var result: bool = undefined;
    if (c.napi_strict_equals(env, value, undefinedJS, &result) != .napi_ok) {
        return translate.throw(env, "Failed to compare the value to undefined");
    }
    return result;
}

pub fn getUndefined(env: c.napi_env) !c.napi_value {
    var undefinedJS: c.napi_value = undefined;
    if (c.napi_get_undefined(env, &undefinedJS) != .napi_ok) {
        return throw(env, "Failed to get the undefined value");
    }
    return undefinedJS;
}

pub fn bufferByteLength(env: c.napi_env, value: c.napi_value) !u32 {
    var global: c.napi_value = undefined;
    if (c.napi_get_global(env, &global) != .napi_ok) {
        return translate.throw(env, "Failed to get global object");
    }

    var bufferJS: c.napi_value = undefined;
    if (c.napi_get_named_property(env, global, "Buffer", &bufferJS) != .napi_ok) {
        return translate.throw(env, "Failed to get the Buffer constructor");
    }

    var byteLengthJS: c.napi_value = undefined;
    if (c.napi_get_named_property(env, bufferJS, "byteLength", &byteLengthJS) != .napi_ok) {
        return translate.throw(env, "Failed to get Buffer.byteLength");
    }

    var returned: c.napi_value = undefined;
    if (c.napi_call_function(env, bufferJS, byteLengthJS, 1, &value, &returned) != .napi_ok) {
        return translate.throw(env, "Failed to call Buffer.byteLength");
    }

    var result: u32 = undefined;
    if (c.napi_get_value_uint32(env, returned, &result) != .napi_ok) {
        return translate.throw(env, "Failed to get the return value of Buffer.byteLength");
    }
    return result;
}

pub fn u32ToJS(env: c.napi_env, value: u32) !c.napi_value {
    var result: c.napi_value = undefined;
    if (c.napi_create_uint32(env, value, &result) != .napi_ok) {
        return translate.throw(env, "Failed to create a uint32");
    }
    return result;
}

pub fn i32ToJS(env: c.napi_env, value: i32) !c.napi_value {
    var result: c.napi_value = undefined;
    if (c.napi_create_int32(env, value, &result) != .napi_ok) {
        return translate.throw(env, "Failed to create a int32");
    }
    return result;
}

