const std = @import("std");
const lex = @import("lexer.zig");
const Tp = @import("types.zig");
const Ast = @import("ast.zig");
pub const ErrorInfo = union(enum) {
    UnknownTypeToken: lex.Token,
    EmptyBlock: struct { leftBrace: lex.Token, rightBrace: lex.Token },
    VariableDoesntExist: lex.Token,
    VariableRedeclaration: struct {
        ogDecl: Ast.AstRef,
        redecl: Ast.AstRef,
    },
    ParamSizeMismatch: struct {
        expectedSize: usize,
        expectedFrom: Ast.AstRef,
        actualSize: usize,
        actualFrom: Ast.AstRef,
    },
    UnexpectedToken: struct {
        got: lex.Token,
        expected: lex.TokenType,
        expected2: ?lex.TokenType,
        expected3: ?lex.TokenType,
        expected4: ?lex.TokenType,
        expected5: ?lex.TokenType,
        expected6: ?lex.TokenType,
    },
    OutOfMemory,
    TypeMismatch: struct {
        left: Ast.AstRef,
        right: ?Ast.AstRef,
        leftTp: Tp.TypeRef,
        rightTp: Tp.TypeRef,
        whileEvaluating: Ast.AstRef,
    },
    UnexpectedType: struct {
        got: Ast.AstRef,
        gotTp: Tp.TypeRef,
        expected: Tp.TypeRef,
        from: ?Ast.AstRef,
    },

    pub fn prettyPrint(
        self: *const ErrorInfo,
        writer: *std.Io.Writer,
        lexer: *lex.Lexer,
    ) !void {
        switch (self.*) {
            .EmptyBlock => |v| {
                _ = try writer.print(
                    "Unexpected empty block on line {}\n",
                    .{lexer.getLineFor(v.leftBrace.startPos)},
                );
            },
            .VariableDoesntExist => |v| {
                const str = switch (v.tok) {
                    .Ident => |str| str,
                    else => unreachable,
                };
                _ = try writer.print(
                    "Variable {s} not found on line {}\n",
                    .{ str, lexer.getLineFor(v.startPos) },
                );
            },
            .VariableRedeclaration => |v| {
                _ = try writer.print(
                    "On line {}, variable redeclared\n",
                    .{lexer.getLineFor(v.redecl.getNode().getLeftRange())},
                );
                _ = try writer.print(
                    "  Note: variable first declared on line {}\n",
                    .{lexer.getLineFor(v.ogDecl.getNode().getLeftRange())},
                );
            },
            .ParamSizeMismatch => |v| {
                _ = try writer.print(
                    "On line {}, parameter size mismatch\n",
                    .{
                        lexer.getLineFor(v.actualFrom.getNode().getLeftRange()),
                    },
                );
                _ = try writer.print(
                    "  Note: expected {} parameters, but got {}\n",
                    .{ v.expectedSize, v.actualSize },
                );
                _ = try writer.print(
                    "  Note: expected because of declaration on line {}: {s}\n",
                    .{
                        lexer.getLineFor(v.expectedFrom.getNode().getLeftRange()),
                        v.expectedFrom.getNode().getString(lexer),
                    },
                );
                _ = try writer.print(
                    "  Note: but got {s}\n",
                    .{v.actualFrom.getNode().getString(lexer)},
                );
            },
            .UnexpectedToken => |v| {
                _ = try writer.print(
                    "On line {}, unexpected token {}\n",
                    .{ lexer.getLineFor(v.got.startPos), v.got.tok },
                );
                _ = try writer.write("  Note: expected one of: \n");
                _ = try writer.print("    {}\n", .{v.expected});
                if (v.expected2) |exp| _ = try writer.print(
                    "    {}\n",
                    .{exp},
                );
                if (v.expected3) |exp| _ = try writer.print(
                    "    {}\n",
                    .{exp},
                );
                if (v.expected4) |exp| _ = try writer.print(
                    "    {}\n",
                    .{exp},
                );
                if (v.expected5) |exp| _ = try writer.print(
                    "    {}\n",
                    .{exp},
                );
                if (v.expected6) |exp| _ = try writer.print(
                    "    {}\n",
                    .{exp},
                );
            },
            .TypeMismatch => |v| {
                _ = try writer.print("Type mismatch error\n", .{});
                _ = try writer.print(
                    "  Note: left side {s} results in type ",
                    .{v.left.getNode().getString(lexer)},
                );
                try v.leftTp.getNode().prettyPrint(writer);
                _ = try writer.print("\n", .{});
                if (v.right) |right| {
                    _ = try writer.print(
                        "  Note: right side {s} results in type ",
                        .{right.getNode().getString(lexer)},
                    );
                } else {
                    _ = try writer.print("  Note: Expected type ", .{});
                }
                try v.rightTp.getNode().prettyPrint(writer);
                _ = try writer.print("\n", .{});
                _ = try writer.print(
                    "  Note: while evaluating {s} \n",
                    .{v.whileEvaluating.getNode().getString(lexer)},
                );
            },
            .UnknownTypeToken => |v| {
                const str = switch (v.tok) {
                    .Ident => |str| str,
                    else => unreachable,
                };
                _ = try writer.print(
                    "Unkown type token {s} on line {}\n",
                    .{ str, lexer.getLineFor(v.startPos) },
                );
            },
            .UnexpectedType => |v| {
                _ = try writer.print("Error unexpected type ", .{});
                try v.gotTp.getNode().prettyPrint(writer);
                _ = try writer.print("\n  Note: Expected ", .{});
                try v.expected.getNode().prettyPrint(writer);
                _ = try writer.print(
                    "\n  Note: unexpected type from statement {s} \n",
                    .{v.got.getNode().getString(lexer)},
                );
                if (v.from) |from| {
                    _ = try writer.print(
                        "\n  Note: exepcted type derived from {s} \n",
                        .{from.getNode().getString(lexer)},
                    );
                }
            },
            else => unreachable,
        }
    }
};

pub fn errEmptyBlock(leftBrace: lex.Token, rightBrace: lex.Token) ParseError {
    Ast.errorBus.append(
        Ast.alloc,
        ErrorInfo{ .EmptyBlock = .{ .leftBrace = leftBrace, .rightBrace = rightBrace } },
    ) catch return ParseError.OutOfMemory;
    return ParseError.EmptyBlock;
}
pub fn errVariableRedecl(ogDecl: Ast.AstRef, newDecl: Ast.AstRef) ParseError {
    Ast.errorBus.append(
        ErrorInfo{ .VariableRedeclaration = .{ .ogDecl = ogDecl, .redecl = newDecl } },
    ) catch return ParseError.OutOfMemory;
    return ParseError.VariableRedeclaration;
}
pub fn errVarNotExist(variable: lex.Token) ParseError {
    Ast.errorBus.append(ErrorInfo{ .VariableDoesntExist = variable }) catch
        return ParseError.OutOfMemory;
    return ParseError.VariableDoesntExist;
}

fn itemOrNull(tp: type, slice: []const tp, item: usize) ?tp {
    if (item >= slice.len) {
        return null;
    }
    return slice[item];
}

pub fn errUnexpectedToken(got: lex.Token, expected: anytype) ParseError {
    const info = @typeInfo(@TypeOf(expected));
    const slice: []const lex.TokenType = switch (info) {
        .array => |a| blk: {
            comptime if (a.child != lex.TokenType) unreachable;
            break :blk expected[0..a.len];
        },
        else => unreachable,
    };
    Ast.errorBus.append(Ast.alloc, ErrorInfo{ .UnexpectedToken = .{
        .got = got,
        .expected = slice[0],
        .expected2 = itemOrNull(lex.TokenType, slice, 1),
        .expected3 = itemOrNull(lex.TokenType, slice, 2),
        .expected4 = itemOrNull(lex.TokenType, slice, 3),
        .expected5 = itemOrNull(lex.TokenType, slice, 4),
        .expected6 = itemOrNull(lex.TokenType, slice, 5),
    } }) catch return ParseError.OutOfMemory;
    return ParseError.UnexpectedToken;
}
pub fn errTypeMismatch(
    left: Ast.AstRef,
    right: ?Ast.AstRef,
    leftTp: Tp.TypeRef,
    rightTp: Tp.TypeRef,
    evaluating: Ast.AstRef,
) ParseError {
    Ast.errorBus.append(
        ErrorInfo{ .TypeMismatch = .{
            .left = left,
            .right = right,
            .leftTp = leftTp,
            .rightTp = rightTp,
            .whileEvaluating = evaluating,
        } },
    ) catch return ParseError.OutOfMemory;
    return ParseError.TypeMismatch;
}
pub fn errUnexpectedType(
    got: Ast.AstRef,
    gotTp: Tp.TypeRef,
    expected: Tp.TypeRef,
    from: ?Ast.AstRef,
) ParseError {
    Ast.errorBus.append(ErrorInfo{ .UnexpectedType = .{
        .got = got,
        .gotTp = gotTp,
        .expected = expected,
        .from = from,
    } }) catch return ParseError.OutOfMemory;
    return ParseError.UnexpectedType;
}

pub fn errParamMismatch(
    expectedSize: usize,
    expectedFrom: Ast.AstRef,
    actualSize: usize,
    actualFrom: Ast.AstRef,
) ParseError {
    Ast.errorBus.append(ErrorInfo{ .ParamSizeMismatch = .{
        .expectedSize = expectedSize,
        .expectedFrom = expectedFrom,
        .actualSize = actualSize,
        .actualFrom = actualFrom,
    } }) catch return ParseError.OutOfMemory;
    return ParseError.ParamSizeMismatch;
}

pub const ParseError = error{
    ParamSizeMismatch,
    UnknownTypeToken,
    EmptyBlock,
    VariableDoesntExist,
    VariableRedeclaration,
    UnexpectedToken,
    OutOfMemory,
    TypeMismatch,
    UnexpectedType,
} || lex.LexerError;
