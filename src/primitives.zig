pub const Integer = isize;
pub const IntegerU = usize;
pub const Float = @Type(.{ .Float = .{ .bits = @bitSizeOf(usize) } });
