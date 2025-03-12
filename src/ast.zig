const std = @import("std");
const Tp = @import("types.zig");
const lex = @import("lexer.zig");
const Err = @import("error.zig");
const scope = @import("scope.zig");
pub const AstRef = struct {
    value: usize,
    pub fn init(value: usize) AstRef {
        return .{ .value = value };
    }
    pub fn getNode(self: AstRef) *Ast {
        return &astNodes.items[self.value];
    }
    pub fn eq(self: AstRef, other: AstRef) bool {
        return self.value == other.value;
    }
};
pub var astNodes: std.ArrayList(Ast) = undefined;
pub var errorBus: std.ArrayList(Err.ErrorInfo) = undefined;
pub var typeTree: std.ArrayList(Tp.Type) = undefined;
pub const Ast = union(enum) {
    Float: lex.Token,
    Int: lex.Token,
    String: lex.Token,
    Ident: lex.Token,
    RawType: lex.Token,
    Declaration: struct {
        keyword: lex.Token,
        name: AstRef,
        tp: ?AstRef,
        value: AstRef,
    },
    FunctionParameterDecl: struct {
        name: lex.Token,
        tp: AstRef,
        next: ?AstRef,
    },
    FunctionCall: struct {
        name: lex.Token,
        params: ?AstRef,
        closingParen: lex.Token,
    },
    FunctionCallParam: struct {
        value: AstRef,
        next: ?AstRef,
    },
    // FunctionForwardDecl: struct {
    //     keyword: lex.Token,
    //     name: AstRef,
    //     params: ?AstRef,
    //     ret: AstRef,
    // },
    FunctionDecl: struct {
        keyword: lex.Token,
        name: AstRef,
        ret: ?AstRef,
        params: ?AstRef,
        where: ?AstRef,
        block: AstRef,
    },
    VariableAccess: lex.Token,
    TypeArrayOf: AstRef,
    ArrayLiteral: ArrayLiteralTp,
    ArrayLiteralContinuation: ArrayLiteralTp,
    ArrayAccess: BinOp,
    TypeTupleOf: struct {
        token: lex.Token,
        tp: ?AstRef,
        next: ?AstRef,
    },
    Statement: struct {
        ast: AstRef,
        next: ?AstRef,
    },
    Return: struct {
        token: lex.Token,
        value: AstRef,
    },
    Add: BinOp,
    Sub: BinOp,
    Equals: BinOp,
    pub const BinOp = struct {
        left: AstRef,
        right: AstRef,
    };
    pub const ArrayLiteralTp = struct {
        token: lex.Token,
        value: ?AstRef,
        next: ?AstRef,
    };
    pub const Range = struct {
        start: usize,
        end: usize,
    };
    pub fn getLeftRange(self: *Ast) usize {
        return switch (self.*) {
            .String => |v| v.startPos,
            .Ident => |v| v.startPos,
            .RawType => |v| v.startPos,
            .VariableAccess => |v| v.startPos,
            .Float => |v| v.startPos,
            .Int => |v| v.startPos,
            .Declaration => |v| v.keyword.startPos,
            .TypeArrayOf => |v| v.getNode().getLeftRange(),
            .ArrayLiteral => |v| v.token.startPos,
            .ArrayLiteralContinuation => |v| if (v.value) |val|
                val.getNode().getLeftRange()
            else
                v.token.startPos,
            .ArrayAccess => |v| v.left.getNode().getLeftRange(),
            .TypeTupleOf => |v| v.token.startPos,
            .Statement => |v| v.ast.getNode().getLeftRange(),
            .Add => |v| v.left.getNode().getLeftRange(),
            .Sub => |v| v.left.getNode().getLeftRange(),
            .Equals => |v| v.left.getNode().getLeftRange(),
            .FunctionParameterDecl => |v| v.name.startPos,
            .FunctionDecl => |v| v.keyword.startPos,
            .FunctionCall => |v| v.name.startPos,
            .FunctionCallParam => |v| v.value.getNode().getLeftRange(),
            .Return => |v| v.token.startPos,
        };
    }
    pub fn getRightRange(self: *Ast) usize {
        return switch (self.*) {
            .String => |v| v.endPos,
            .Ident => |v| v.endPos,
            .RawType => |v| v.endPos,
            .VariableAccess => |v| v.endPos,
            .Float => |v| v.endPos,
            .Int => |v| v.endPos,
            .Declaration => |v| v.value.getNode().getRightRange(),
            .TypeArrayOf => |v| v.getNode().getRightRange(),
            .ArrayLiteral => |v| if (v.next) |next|
                next.getNode().getRightRange()
            else if (v.value) |val|
                val.getNode().getRightRange()
            else
                v.token.endPos,
            .ArrayLiteralContinuation => |v| if (v.next) |next|
                next.getNode().getRightRange()
            else
                v.token.endPos,
            .ArrayAccess => |v| v.right.getNode().getRightRange(),
            .TypeTupleOf => |v| if (v.next) |next|
                next.getNode().getRightRange()
            else if (v.tp) |tp|
                tp.getNode().getRightRange()
            else
                v.token.endPos,
            .Statement => |v| if (v.next) |next|
                next.getNode().getRightRange()
            else
                v.ast.getNode().getRightRange(),
            .Add => |v| v.right.getNode().getRightRange(),
            .Sub => |v| v.right.getNode().getRightRange(),
            .Equals => |v| v.right.getNode().getRightRange(),
            .FunctionParameterDecl => |v| if (v.next) |next| next.getNode().getRightRange() else v.tp.getNode().getRightRange(),
            .FunctionDecl => |v| v.block.getNode().getRightRange(),
            .FunctionCall => |v| v.closingParen.endPos,
            .FunctionCallParam => |v| if (v.next) |next|
                next.getNode().getRightRange()
            else
                v.value.getNode().getRightRange(),
            .Return => |v| v.value.getNode().getRightRange(),
        };
    }
    pub fn getRange(self: *Ast) Range {
        return .{
            .start = self.getLeftRange(),
            .end = self.getRightRange(),
        };
    }
    pub fn getString(self: *Ast, lexer: *lex.Lexer) []u8 {
        const range = self.getRange();
        return lexer.str[range.start..range.end];
    }
    pub fn addNode(node: Ast) !AstRef {
        astNodes.append(node) catch return Err.ParseError.OutOfMemory;
        return AstRef.init(astNodes.items.len - 1);
    }
};
pub fn parseAst(lexer: *lex.Lexer) Err.ParseError!?AstRef {
    var rootNode: ?AstRef = null;
    var retNode: ?AstRef = null;
    var returnNode: ?AstRef = null;
    while (true) {
        const ast = switch ((try lexer.getNextToken()).tok) {
            .Return => node: {
                const tok = lexer.currentTok.?;
                const val = try parseValue(lexer);
                const node = try Ast.addNode(.{ .Return = .{ .token = tok, .value = val } });
                returnNode = node;
                try assertSemicolon(lexer);
                break :node node;
            },
            lex.TokenType.Let => node: {
                const decl = try parseVarDecl(lexer);
                try assertSemicolon(lexer);
                break :node decl;
            },
            lex.TokenType.Comment => {
                continue;
            },
            lex.TokenType.Fn => blk: {
                const f = try parseFunction(lexer);
                break :blk f;
            },
            .EOF => {
                break;
            },
            else => {
                return Err.errUnexpectedToken(lexer.currentTok.?, [_]lex.TokenType{ .Let, .{ .Comment = "a" }, .Return, .Fn });
            },
        };
        if (rootNode) |*root| {
            const next = try Ast.addNode(.{ .Statement = .{ .ast = ast, .next = null } });
            switch (root.getNode().*) {
                .Statement => |*v| {
                    v.next = next;
                },
                else => unreachable,
            }
            root.* = next;
        } else {
            rootNode = try Ast.addNode(.{ .Statement = .{ .ast = ast, .next = null } });
        }
        if (retNode == null) {
            retNode = rootNode.?;
        }
        if (lexer.peekNextToken().tok == .RightBrace) {
            break;
        }
    }
    return retNode;
}

pub fn parseBlock(lexer: *lex.Lexer, skipLeftBrace: bool) !AstRef {
    const lb = if (!skipLeftBrace) blk: {
        const lb = try lexer.getNextToken();
        if (lb.tok != lex.TokenType.LeftBrace) {
            return Err.errUnexpectedToken(lb, [_]lex.TokenType{.LeftBrace});
        }
        break :blk lb;
    } else lexer.currentTok.?;
    const retNode = try parseAst(lexer);
    const rb = try lexer.getNextToken();
    if (rb.tok != lex.TokenType.RightBrace) {
        return Err.errUnexpectedToken(rb, [_]lex.TokenType{.RightBrace});
    }
    if (retNode) |ret| return ret;
    return Err.errEmptyBlock(lb, rb);
}

pub fn parseFunction(lexer: *lex.Lexer) !AstRef {
    const fnTok = lexer.currentTok.?;
    const nameTok = try lexer.getNextToken();
    switch (nameTok.tok) {
        .Ident => {},
        else => return Err.errUnexpectedToken(nameTok, [_]lex.TokenType{.{ .Ident = "a" }}),
    }
    const nameNode = try Ast.addNode(.{ .Ident = nameTok });
    const paren = try lexer.getNextToken();
    switch (paren.tok) {
        .LeftParen => {},
        else => return Err.errUnexpectedToken(paren, [_]lex.TokenType{.LeftParen}),
    }
    const params = try parseFunctionParams(lexer);

    const arrowWhereBrace = try lexer.getNextToken();

    switch (arrowWhereBrace.tok) {
        .Arrow => {
            const ret = try parseType(lexer);
            const block = try parseBlock(lexer, false);
            return Ast.addNode(.{ .FunctionDecl = .{
                .keyword = fnTok,
                .where = null,
                .name = nameNode,
                .params = params,
                .ret = ret,
                .block = block,
            } });
        },
        .Where => {
            const where = try parseValue(lexer);
            const block = try parseBlock(lexer, false);
            return Ast.addNode(.{ .FunctionDecl = .{
                .ret = null,
                .keyword = fnTok,
                .params = params,
                .where = where,
                .name = nameNode,
                .block = block,
            } });
        },
        else => return Err.errUnexpectedToken(paren, [_]lex.TokenType{
            .Arrow,
            .Where,
        }),
    }
}

pub fn parseFunctionParams(lexer: *lex.Lexer) !?AstRef {
    const nameTok = try lexer.getNextToken();
    switch (nameTok.tok) {
        .Ident => {},
        .RightParen => return null,
        else => return Err.errUnexpectedToken(
            nameTok,
            [_]lex.TokenType{
                .{ .Ident = "a" },
                .RightParen,
            },
        ),
    }
    const colon = try lexer.getNextToken();
    switch (colon.tok) {
        .Colon => {},
        else => return Err.errUnexpectedToken(nameTok, [_]lex.TokenType{.Colon}),
    }
    const tp = try parseType(lexer);
    const commaOrParen = try lexer.getNextToken();
    const next = switch (commaOrParen.tok) {
        .Comma => try parseFunctionParams(lexer),
        .RightParen => null,
        else => return Err.errUnexpectedToken(nameTok, [_]lex.TokenType{
            .Comma,
            .RightParen,
        }),
    };

    return try Ast.addNode(.{
        .FunctionParameterDecl = .{
            .name = nameTok,
            .tp = tp,
            .next = next,
        },
    });
}
pub fn parseType(lexer: *lex.Lexer) !AstRef {
    const token = try lexer.getNextToken();
    switch (token.tok) {
        .Ident => {
            return try Ast.addNode(.{ .RawType = token });
        },
        .LeftSqBracket => {
            const tp = try parseType(lexer);
            const next = try lexer.getNextToken();
            if (next.tok != lex.TokenType.RightSqBracket) {
                return Err.errUnexpectedToken(next, [_]lex.TokenType{lex.TokenType.RightSqBracket});
            }
            return try Ast.addNode(.{ .TypeArrayOf = tp });
        },
        else => {
            return Err.errUnexpectedToken(token, [_]lex.TokenType{
                .{ .Ident = "a" },
                .LeftSqBracket,
            });
        },
    }
    return Err.errUnexpectedToken(token, [_]lex.TokenType{.{ .Ident = "a" }});
}
pub fn parseArray(lexer: *lex.Lexer) !AstRef {
    var literal: Ast.ArrayLiteralTp = .{
        .token = lexer.currentTok.?,
        .value = null,
        .next = null,
    };
    var lastNode: ?AstRef = null;
    var retNode: ?AstRef = null;
    switch (lexer.peekNextToken().tok) {
        .RightSqBracket => {
            _ = try lexer.getNextToken();
            return Ast.addNode(.{ .ArrayLiteral = literal });
        },
        else => {},
    }
    var first = true;
    while (true) {
        const value = try parseValue(lexer);
        literal.value = value;

        const commaOrBracket = try lexer.getNextToken();
        if (!first) {
            literal.token = commaOrBracket;
        }
        first = false;
        const node = if (lastNode) |_|
            try Ast.addNode(.{ .ArrayLiteralContinuation = literal })
        else
            try Ast.addNode(.{ .ArrayLiteral = literal });

        if (lastNode) |v| {
            switch (v.getNode().*) {
                .ArrayLiteral => |*lit| {
                    lit.next = node;
                },
                .ArrayLiteralContinuation => |*lit| {
                    lit.next = node;
                },
                else => unreachable,
            }
        }
        if (retNode == null) {
            retNode = node;
        }
        lastNode = node;
        switch (commaOrBracket.tok) {
            .Comma => {},
            .RightSqBracket => break,
            else => {
                return Err.errUnexpectedToken(commaOrBracket, [_]lex.TokenType{
                    .Comma,
                    .RightSqBracket,
                });
            },
        }
    }
    return retNode.?;
}

pub fn parseFunctionCallParams(lexer: *lex.Lexer) Err.ParseError!?AstRef {
    if (lexer.peekNextToken().tok == .RightParen) {
        _ = try lexer.getNextToken();
        return null;
    }
    const value = try parseValue(lexer);
    const nextTok = try lexer.getNextToken();
    const next = switch (nextTok.tok) {
        .Comma => try parseFunctionCallParams(lexer),
        .RightParen => null,
        else => return Err.errUnexpectedToken(nextTok, [_]lex.TokenType{
            .{ .IntLiteral = 0 },
            .{ .FloatLiteral = 0 },
            .LeftSqBracket,
            .{ .Ident = "a" },
        }),
    };
    return try Ast.addNode(.{ .FunctionCallParam = .{ .next = next, .value = value } });
}
pub fn parseValue(lexer: *lex.Lexer) Err.ParseError!AstRef {
    const token = try lexer.getNextToken();
    var ret =
        if (token.tok == lex.TokenType.IntLiteral)
        try Ast.addNode(.{ .Int = token })
    else if (token.tok == .FloatLiteral)
        try Ast.addNode(.{ .Float = token })
    else if (token.tok == .LeftSqBracket)
        try parseArray(lexer)
    else if (token.tok == .Ident) blk: {
        if (lexer.peekNextToken().tok == .LeftParen) {
            const name = lexer.currentTok.?;
            _ = try lexer.getNextToken();
            const params = try parseFunctionCallParams(lexer);
            break :blk try Ast.addNode(.{ .FunctionCall = .{
                .name = name,
                .params = params,
                .closingParen = lexer.currentTok.?,
            } });
        } else {
            break :blk try Ast.addNode(.{ .VariableAccess = token });
        }
    } else {
        return Err.errUnexpectedToken(token, [_]lex.TokenType{
            .{ .IntLiteral = 0 },
            .{ .FloatLiteral = 0 },
            .LeftSqBracket,
            .{ .Ident = "a" },
        });
    };

    switch (lexer.peekNextToken().tok) {
        .OpPls => {
            _ = try lexer.getNextToken();
            const right = try parseValue(lexer);
            ret = try Ast.addNode(.{ .Add = .{ .left = ret, .right = right } });
        },
        .OpMns => {
            _ = try lexer.getNextToken();
            const right = try parseValue(lexer);
            ret = try Ast.addNode(.{ .Sub = .{ .left = ret, .right = right } });
        },
        .OpEqEq => {
            _ = try lexer.getNextToken();
            const right = try parseValue(lexer);
            ret = try Ast.addNode(.{ .Equals = .{ .left = ret, .right = right } });
        },
        .LeftSqBracket => {
            _ = try lexer.getNextToken();
            const right = try parseValue(lexer);
            ret = try Ast.addNode(.{ .ArrayAccess = .{ .left = ret, .right = right } });

            const next = try lexer.getNextToken();
            if (next.tok != lex.TokenType.RightSqBracket) {
                return Err.errUnexpectedToken(token, [_]lex.TokenType{.RightSqBracket});
            }
        },
        else => {},
    }
    return ret;
}
pub fn parseVarDecl(lexer: *lex.Lexer) !AstRef {
    const letToken = lexer.currentTok.?;
    const name = try lexer.getNextToken();
    if (name.tok != lex.TokenType.Ident) {
        return Err.errUnexpectedToken(name, [_]lex.TokenType{lex.TokenType{ .Ident = "a" }});
    }
    const colonOrEquals = try lexer.getNextToken();
    const nameNode = try Ast.addNode(.{ .Ident = name });

    const typeNode = if (colonOrEquals.tok == lex.TokenType.Colon)
        try parseType(lexer)
    else
        null;
    if (typeNode != null) {
        const eq = try lexer.getNextToken();
        if (eq.tok != lex.TokenType.OpEq) {
            return Err.errUnexpectedToken(eq, [_]lex.TokenType{lex.TokenType.OpEq});
        }
    }
    const valueNode = try parseValue(lexer);

    return try Ast.addNode(.{
        .Declaration = .{
            .keyword = letToken,
            .name = nameNode,
            .tp = typeNode,
            .value = valueNode,
        },
    });
}

pub fn assertSemicolon(lexer: *lex.Lexer) !void {
    const tok = try lexer.getNextToken();
    if (tok.tok != lex.TokenType.Semicolon) {
        return Err.errUnexpectedToken(tok, [_]lex.TokenType{.Semicolon});
    }
}
pub fn assertComma(lexer: *lex.Lexer) !void {
    const tok = try lexer.getNextToken();
    if (tok.tok != lex.TokenType.Comma) {
        return Err.errUnexpectedToken(tok, [_]lex.TokenType{.Comma});
    }
}
