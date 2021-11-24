pub const STRING = 0b000;
pub const BUFFER = 0b001;
pub const INT = 0b010; // 32-bit integer
pub const DOUBLE = 0b011; // use next 8 bytes to encode 64-bit float
pub const ARRAY = 0b100;
pub const OBJECT = 0b101;
pub const BOOLNULL = 0b110; // the rest of the byte is for true/false/null/undefined
pub const RESERVED = 0b111;

pub const TAG_SIZE: u8 = 3;
pub const TAG_MASK = 0b111;
