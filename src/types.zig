const std = @import("std");
const scope = @import("scope.zig");
const Err = @import("error.zig");
const Ast = @import("ast.zig");
pub const TypeRef = struct {
    value: usize,
    pub fn init(value: usize) TypeRef {
        return .{ .value = value };
    }
    pub fn getNode(self: TypeRef) *Type {
        return &Ast.typeTree.items[self.value];
    }
    pub fn eq(self: TypeRef, other: TypeRef) bool {
        return self.value == other.value;
    }
};
pub const Type = union(enum) {
    Int,
    Float,
    Bool,
    Generic: struct { name: []const u8, currentTp: TypeRef },
    ArrayOf: TypeRef,
    Function: struct {
        ret: TypeRef,
        params: ?TypeRef,
    },
    FunctionParam: struct {
        tp: TypeRef,
        next: ?TypeRef,
    },
    Any,
    Never,
    Void,
    pub fn equals(left: Type, right: Type) bool {
        if (!std.mem.eql(u8, @tagName(left), @tagName(right))) {
            return false;
        }
        // TODO: Functions
        switch (left) {
            .ArrayOf => |l| {
                _ = typesEqual(l, switch (right) {
                    .ArrayOf => |r| r,
                    else => unreachable,
                }, Ast.AstRef.init(0), Ast.AstRef.init(0), Ast.AstRef.init(0)) catch {
                    _ = Ast.errorBus.pop();
                    return false;
                };
            },
            else => {},
        }
        return true;
    }
    pub fn prettyPrint(self: *Type, writer: std.io.AnyWriter) !void {
        switch (self.*) {
            .Generic => |v| _ = try writer.write(v.name),
            .Bool => _ = try writer.write("bool"),
            .Int => _ = try writer.write("int"),
            .Float => _ = try writer.write("float"),
            .Void => _ = try writer.write("void"),
            .Never => _ = try writer.write("!never"),
            .Any => _ = try writer.write("any"),
            .ArrayOf => |v| {
                _ = try writer.write("[");
                try v.getNode().prettyPrint(writer);
                _ = try writer.write("]");
            },
            .Function => |v| {
                _ = try writer.write("fn (");
                if (v.params) |params| {
                    try params.getNode().prettyPrint(writer);
                }
                _ = try writer.write(") -> ");
                try v.ret.getNode().prettyPrint(writer);
            },
            .FunctionParam => |v| {
                try v.tp.getNode().prettyPrint(writer);
                if (v.next) |next| {
                    _ = try writer.write(", ");
                    try next.getNode().prettyPrint(writer);
                }
            },
        }
    }
};

pub fn getTypeRefFor(inTp: Type) Err.ParseError!TypeRef {
    for (Ast.typeTree.items, 0..) |tp, i| {
        if (tp.equals(inTp)) {
            return TypeRef.init(i);
        }
    }
    Ast.typeTree.append(inTp) catch return Err.ParseError.OutOfMemory;
    return TypeRef.init(Ast.typeTree.items.len - 1);
}

pub fn typesEqual(
    left: TypeRef,
    right: TypeRef,
    leftAst: Ast.AstRef,
    rightAst: Ast.AstRef,
    astFrom: Ast.AstRef,
) Err.ParseError!TypeRef {
    if (left.eq(right)) {
        return left;
    }
    if (left.getNode().* == .Never) {
        return right;
    }
    if (right.getNode().* == .Never) {
        return left;
    }
    return Err.errTypeMismatch(leftAst, rightAst, left, right, astFrom);
}
pub fn typesEqualNoRight(
    left: TypeRef,
    right: TypeRef,
    leftAst: Ast.AstRef,
    astFrom: Ast.AstRef,
) Err.ParseError!TypeRef {
    if (left.eq(right)) {
        return left;
    }
    if (left.getNode().* == .Never) {
        return right;
    }
    if (right.getNode().* == .Never) {
        return left;
    }
    return Err.errTypeMismatch(leftAst, null, left, right, astFrom);
}

pub fn getParamCount(ast: ?Ast.AstRef) usize {
    if (ast) |a| {
        switch (a.getNode().*) {
            .FunctionParameterDecl => |v| {
                return 1 + getParamCount(v.next);
            },
            .FunctionCallParam => |v| {
                return 1 + getParamCount(v.next);
            },
            .FunctionTypeParams => |v| {
                return 1 + getParamCount(v.next);
            },
            else => {
                std.debug.print("OMG {}", .{a.getNode().*});
                unreachable;
            },
        }
    }
    return 0;
}

pub fn assertParamSizeMatch(
    leftAst: ?Ast.AstRef,
    rightAst: ?Ast.AstRef,
    redeclAst: Ast.AstRef,
    declAst: Ast.AstRef,
) Err.ParseError!void {
    if (getParamCount(leftAst) != getParamCount(rightAst)) {
        return Err.errParamMismatch(
            getParamCount(leftAst),
            redeclAst,
            getParamCount(rightAst),
            declAst,
        );
    }
}
pub fn assertCallParamsMatch(
    newAst: ?Ast.AstRef,
    declAst: ?Ast.AstRef,
    ogDeclAst: Ast.AstRef,
    scopes: *scope.Scopes,
) Err.ParseError!void {
    // NOTE: this assumes assertParamSizeMatch called first
    if (newAst == null or declAst == null) {
        return;
    }

    switch (newAst.?.getNode().*) {
        .FunctionCallParam => |v1| {
            switch (declAst.?.getNode().*) {
                .FunctionParameterDecl => |v2| {
                    _ = try typesEqual(
                        try getType(v1.value, scopes),
                        try parseTypeExpression(v2.tp),
                        v1.value,
                        v2.tp,
                        ogDeclAst,
                    );
                    try assertCallParamsMatch(v1.next, v2.next, ogDeclAst, scopes);
                },
                .FunctionTypeParams => |v2| {
                    _ = try typesEqual(
                        try getType(v1.value, scopes),
                        try parseTypeExpression(v2.tp),
                        v1.value,
                        v2.tp,
                        ogDeclAst,
                    );
                    try assertCallParamsMatch(v1.next, v2.next, ogDeclAst, scopes);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub fn assertParamsMatch(
    newAst: ?Ast.AstRef,
    declAst: ?Ast.AstRef,
    ogDeclAst: Ast.AstRef,
) Err.ParseError!void {
    // NOTE: this assumes assertParamSizeMatch called first
    if (newAst == null or declAst == null) {
        return;
    }

    switch (newAst.?.getNode().*) {
        .FunctionParameterDecl => |v1| {
            switch (declAst.?.getNode().*) {
                .FunctionParameterDecl => |v2| {
                    _ = try typesEqual(
                        try parseTypeExpression(v1.tp),
                        try parseTypeExpression(v2.tp),
                        v1.tp,
                        v2.tp,
                        ogDeclAst,
                    );
                    try assertParamsMatch(v1.next, v2.next, ogDeclAst);
                },
                else => unreachable,
            }
        },
        else => {
            std.debug.print("YO {}", .{newAst.?.getNode().*});
            unreachable;
        },
    }
}

pub fn addParams(ast: ?Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!void {
    if (ast == null) return;
    switch (ast.?.getNode().*) {
        .FunctionParameterDecl => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            const tp = try parseTypeExpression(v.tp);
            switch (tp.getNode().*) {
                .Function => {
                    try scopes.addDefaultFunction(name, ast.?, tp);
                },
                else => {
                    try scopes.addVar(name, tp, ast.?);
                },
            }
            try addParams(v.next, scopes);
        },
        else => unreachable,
    }
}

pub fn assertTypeCanMath(tp: TypeRef, gotAst: Ast.AstRef) Err.ParseError!void {
    switch (tp.getNode().*) {
        .Int, .Float => {},
        else => return Err.errUnexpectedType(
            gotAst,
            tp,
            try getTypeRefFor(.Float),
            null,
        ),
    }
}

pub fn getType(ast: Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!TypeRef {
    switch (ast.getNode().*) {
        .True => return getTypeRefFor(Type.Bool),
        .False => return getTypeRefFor(Type.Bool),
        .Int => return getTypeRefFor(Type.Int),
        .Float => return getTypeRefFor(Type.Float),

        // TODO: Make this use from getType(v.fnAst)
        .FunctionCall => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            const fun = try scopes.getFunction(name, v.name);
            const FunNode = struct {
                ret: Ast.AstRef,
                params: ?Ast.AstRef,
            };
            const funNode: FunNode = switch (fun.decl.getNode().*) {
                .FunctionDecl => |r| .{
                    .ret = r.ret.?,
                    .params = r.params,
                },
                .FunctionParameterDecl => |r| switch (r.tp.getNode().*) {
                    .FunctionType => |t| .{
                        .ret = t.ret,
                        .params = t.params,
                    },
                    else => unreachable,
                },
                else => {
                    std.debug.print("YO {}", .{fun.decl.getNode().*});
                    unreachable;
                },
            };
            const retNode = funNode.ret;
            try assertParamSizeMatch(v.params, funNode.params, ast, fun.decl);
            try assertCallParamsMatch(v.params, funNode.params, fun.decl, scopes);
            return try parseTypeExpression(retNode);
        },
        .FunctionDecl => |v| {
            const nameTok = switch (v.name.getNode().*) {
                .Ident => |i| i,
                else => unreachable,
            };
            const name = switch (nameTok.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            var retNode: Ast.AstRef = undefined;
            const expectedRet =
                if (v.ret) |ret|
            blk: {
                const params = if (v.params) |params|
                    try parseTypeExpression(params)
                else
                    null;
                const retTp = try parseTypeExpression(ret);
                try scopes.addDefaultFunction(name, ast, try getTypeRefFor(.{
                    .Function = .{ .params = params, .ret = retTp },
                }));
                retNode = ret;
                break :blk retTp;
            } else blk: {
                const fun = try scopes.getFunction(name, nameTok);
                const funNode = switch (fun.decl.getNode().*) {
                    .FunctionDecl => |r| r,
                    else => unreachable,
                };
                retNode = funNode.ret.?;
                try assertParamSizeMatch(v.params, funNode.params, ast, fun.decl);
                try assertParamsMatch(v.params, funNode.params, fun.decl);
                try scopes.addFunction(name, nameTok);
                const ret = funNode.ret.?;
                break :blk try parseTypeExpression(ret);
            };
            try scopes.addScope();
            defer scopes.popScope();
            try addParams(v.params, scopes);
            if (v.where) |where| {
                _ = try typesEqualNoRight(
                    try getType(where, scopes),
                    try getTypeRefFor(Type.Bool),
                    where,
                    ast,
                );
            }
            const blockType = try getType(v.block, scopes);
            _ = try typesEqual(expectedRet, blockType, retNode, v.block, ast);
            return getTypeRefFor(Type.Void);
        },
        .Add => |v| {
            const left = try getType(v.left, scopes);
            const right = try getType(v.right, scopes);
            try assertTypeCanMath(left, v.left);
            try assertTypeCanMath(right, v.right);
            return try typesEqual(left, right, v.left, v.right, ast);
        },
        .Sub => |v| {
            const left = try getType(v.left, scopes);
            const right = try getType(v.right, scopes);
            try assertTypeCanMath(left, v.left);
            try assertTypeCanMath(right, v.right);
            return try typesEqual(left, right, v.left, v.right, ast);
        },
        .Equals => |v| {
            const left = try getType(v.left, scopes);
            const right = try getType(v.right, scopes);
            _ = try typesEqual(left, right, v.left, v.right, ast);
            return getTypeRefFor(Type.Bool);
        },
        .Declaration => |v| {
            const actual = try getType(v.value, scopes);
            const name = switch (v.name.getNode().*) {
                .Ident => |tok| switch (tok.tok) {
                    .Ident => |str| str,
                    else => unreachable,
                },
                else => unreachable,
            };
            if (v.tp) |tp| {
                const expected = try parseTypeExpression(tp);
                _ = try typesEqual(expected, actual, tp, v.value, ast);
            }
            try scopes.addVar(name, actual, ast);
            return getTypeRefFor(Type.Void);
        },
        .ArrayLiteral => |v| {
            const tp = if (v.value) |val|
                try getType(val, scopes)
            else
                return getTypeRefFor(.{
                    .ArrayOf = try getTypeRefFor(Type.Never),
                });
            if (v.next) |next| {
                _ = try typesEqual(tp, try getType(next, scopes), v.value.?, next, ast);
            }
            return try getTypeRefFor(.{ .ArrayOf = tp });
        },
        .ArrayLiteralContinuation => |v| {
            const value = if (v.value) |val|
                try getType(val, scopes)
            else
                return try getTypeRefFor(Type.Never);
            if (v.next) |next| {
                _ = try typesEqual(value, try getType(
                    next,
                    scopes,
                ), v.value.?, next, ast);
            }
            return value;
        },
        .FunctionAccess => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            return (try scopes.getFunction(name, v.name)).tp;
        },
        // TODO: Make this support getting functions and variables
        .VariableAccess => |v| {
            const name = switch (v.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            return scopes.getVar(name, v);
        },
        .ArrayAccess => |v| {
            const left = try getType(v.left, scopes);
            const right = try getType(v.right, scopes);
            _ = try typesEqualNoRight(right, try getTypeRefFor(Type.Int), v.right, ast);
            const actualType = switch (left.getNode().*) {
                .ArrayOf => |tp| tp,
                else => {
                    return Err.errUnexpectedType(v.left, left, try getTypeRefFor(.{
                        .ArrayOf = try getTypeRefFor(Type.Any),
                    }), null);
                },
            };
            return actualType;
        },
        .Statement => |v| {
            const ret = try getType(v.ast, scopes);
            if (v.next) |next| {
                return try getType(next, scopes);
            }
            return ret;
        },
        .Return => |v| {
            return try getType(v.value, scopes);
        },
        else => {
            std.debug.print("YO: {}\n", .{ast.getNode().*});
            unreachable;
        },
    }
}

pub fn parseTypeExpression(ast: Ast.AstRef) Err.ParseError!TypeRef {
    switch (ast.getNode().*) {
        .RawType => |tok| {
            switch (tok.tok) {
                .Ident => |str| {
                    if (std.mem.eql(u8, str, "int")) {
                        return getTypeRefFor(Type.Int);
                    }
                    if (std.mem.eql(u8, str, "float")) {
                        return getTypeRefFor(Type.Float);
                    }
                    if (std.mem.eql(u8, str, "bool")) {
                        return getTypeRefFor(Type.Bool);
                    }
                    return Err.ParseError.UnknownTypeToken;
                },
                else => unreachable,
            }
        },
        .TypeArrayOf => |v| {
            return getTypeRefFor(.{ .ArrayOf = try parseTypeExpression(v) });
        },
        .FunctionType => |v| {
            const ret = try parseTypeExpression(v.ret);
            const param = if (v.params) |param| try parseTypeExpression(param) else null;
            return getTypeRefFor(.{ .Function = .{ .ret = ret, .params = param } });
        },
        .FunctionTypeParams => |v| {
            const tp = try parseTypeExpression(v.tp);
            const next = if (v.next) |next| try parseTypeExpression(next) else null;
            return getTypeRefFor(.{ .FunctionParam = .{ .tp = tp, .next = next } });
        },
        .FunctionParameterDecl => |v| {
            const tp = try parseTypeExpression(v.tp);
            const next = if (v.next) |next| try parseTypeExpression(next) else null;
            return getTypeRefFor(.{ .FunctionParam = .{ .tp = tp, .next = next } });
        },

        else => unreachable,
    }
}

pub fn validateStatement(ast: Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!void {
    switch (ast.getNode().*) {
        .Statement => |v| {
            _ = try typesEqualNoRight(
                try getType(v.ast, scopes),
                try getTypeRefFor(Type.Void),
                v.ast,
                ast,
            );
            if (v.next) |next| {
                try validateStatement(next, scopes);
            }
        },
        else => unreachable,
    }
}

pub fn validateTypes(ast: Ast.AstRef, alloc: std.mem.Allocator) Err.ParseError!void {
    var scopes = try scope.Scopes.init(alloc);
    defer scopes.deinit();
    try validateStatement(ast, &scopes);
}
