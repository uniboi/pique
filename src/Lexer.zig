const std = @import("std");

const primitive = @import("primitives.zig");
const Lexer = @This();

pub const Error = error{
    UnknownToken,
    UnknownNumericFormat,
} || std.fmt.ParseIntError;

pub const Token = union(enum) {
    identifier: []const u8,
    integer: primitive.Integer,
    natural_number: primitive.IntegerU,
    float: primitive.Float,

    semicolon,

    // ()
    parenthesis_open,
    parenthesis_close,

    // {}
    bracket_open,
    bracket_close,

    // []
    square_bracket_open,
    square_bracket_close,

    // <>
    angled_bracket_open,
    angled_bracket_close,

    // =
    assign,

    add,
    subtract,
    multiply,
    divide,

    pub fn isDirect(token: Token) bool {
        return switch (token) {
            .semicolon,
            .parenthesis_open,
            .parenthesis_close,
            .bracket_open,
            .bracket_close,
            .square_bracket_open,
            .square_bracket_close,
            .angled_bracket_open,
            .angled_bracket_close,
            .assign,
            .add,
            .subtract,
            .multiply,
            .divide,
            => true,
            else => false,
        };
    }
};

source: []const u8,
position: usize = 0,

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\r' or c == '\n' or c == '\t';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAllowedInIdentifier(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_' or isDigit(c);
}

fn current(lexer: Lexer) u8 {
    return lexer.source[lexer.position];
}

/// Asserts that the first character is known to be a valid identifier
fn identifier(lexer: *Lexer) Token {
    std.debug.assert(isAllowedInIdentifier(lexer.source[lexer.position]));
    const start_pos = lexer.position;
    lexer.position += 1;

    while (isAllowedInIdentifier(lexer.current())) : (lexer.position += 1) {}

    return .{
        .identifier = lexer.source[start_pos..lexer.position],
    };
}

/// Asserts that the first character is a digit or '-'
fn number(lexer: *Lexer) Error!Token {
    std.debug.assert(isDigit(lexer.current()) or lexer.current() == '-');

    const is_signed = lexer.current() == '-';
    var is_float = false;

    const start_pos = lexer.position;
    lexer.position += 1;

    while (isDigit(lexer.current()) or lexer.current() == '.') : (lexer.position += 1) {
        if (lexer.current() == '.') {
            if (is_float) {
                return Error.UnknownNumericFormat;
            }
            is_float = true;
        }
    }

    const number_identifier = lexer.source[start_pos..lexer.position];
    std.debug.print("number {s}\n", .{number_identifier});
    if (is_float) {
        return .{
            .float = try std.fmt.parseFloat(primitive.Float, number_identifier),
        };
    }

    return if (is_signed) .{
        .integer = try std.fmt.parseInt(primitive.Integer, number_identifier, 10),
    } else .{
        .natural_number = try std.fmt.parseInt(primitive.IntegerU, number_identifier, 10),
    };
}

pub fn peek(lexer: Lexer) ?u8 {
    if (lexer.position + 1 > lexer.source.len) {
        return null;
    }

    return lexer.source[lexer.position + 1];
}

pub fn next(lexer: *Lexer) Error!?Token {
    if (lexer.position >= lexer.source.len) {
        return null;
    }

    while (isWhitespace(lexer.source[lexer.position])) : (lexer.position += 1) {}

    const maybe_token: Error!Token = switch (lexer.source[lexer.position]) {
        ';' => .{ .semicolon = {} },
        '(' => .{ .parenthesis_open = {} },
        ')' => .{ .parenthesis_close = {} },
        '{' => .{ .bracket_open = {} },
        '}' => .{ .bracket_close = {} },
        '[' => .{ .square_bracket_open = {} },
        ']' => .{ .square_bracket_close = {} },
        '<' => .{ .angled_bracket_open = {} },
        '>' => .{ .angled_bracket_close = {} },
        '=' => .{ .assign = {} },
        '+' => .{ .add = {} },
        '*' => .{ .multiply = {} },
        '/' => .{ .divide = {} },

        '-' => sub: {
            const following = lexer.peek();
            break :sub if (following != null and isDigit(following.?)) try lexer.number() else .{ .subtract = {} };
        },

        'a'...'z', 'A'...'Z', '_' => lexer.identifier(),

        '0'...'9' => try lexer.number(),

        else => Error.UnknownToken,
    };

    // the compiler is a bit stupid and refused to cast Token to ?Token without this
    const token: Token = try maybe_token;
    if (token.isDirect()) {
        lexer.position += 1;
    }

    return token;
}
