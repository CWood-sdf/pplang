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
    ArrayOf: TypeRef,
    Function: struct {
        ret: TypeRef,
        next: ?TypeRef,
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
                if (v.next) |next| {
                    try next.getNode().prettyPrint(writer);
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

pub fn typesEqual(left: TypeRef, right: TypeRef, leftAst: Ast.AstRef, rightAst: Ast.AstRef, astFrom: Ast.AstRef) Err.ParseError!TypeRef {
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
pub fn typesEqualNoRight(left: TypeRef, right: TypeRef, leftAst: Ast.AstRef, astFrom: Ast.AstRef) Err.ParseError!TypeRef {
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

pub fn assertParamsMatch(newAst: ?Ast.AstRef, declAst: ?Ast.AstRef, ogDeclAst: Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!void {
    if (newAst == null and declAst == null) {
        return;
    }
    switch (newAst.getNode().*) {
        .FunctionParameterDecl => |v1| {
            switch (declAst.getNode().*) {
                .FunctionParameterDecl => |v2| {
                    try typesEqual(try getType(v1.tp, scopes), try getType(v2.tp, scopes), v1, v2, ogDeclAst);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub fn getType(ast: Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!TypeRef {
    switch (ast.getNode().*) {
        .Int => return getTypeRefFor(Type.Int),
        .Float => return getTypeRefFor(Type.Float),
        // .FunctionForwardDecl => |_| {
        //     return getTypeRefFor(Type.Void);
        // },
        .FunctionDecl => |v| {
            const nameTok = switch (v.name.getNode().*) {
                .Ident => |i| i,
                else => unreachable,
            };
            const name = switch (nameTok.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            const expectedRet =
                if (v.ret) |ret|
            blk: {
                try scopes.addDefaultFunction(name, ast);
                break :blk try getType(ret, scopes);
            } else blk: {
                try scopes.addFunction(name, nameTok);
                const fun = try scopes.getFunction(name, nameTok);
                const funNode = switch (fun.decl.getNode().*) {
                    .FunctionDecl => |r| r,
                    else => unreachable,
                };
                try assertParamsMatch(v.params, funNode.params, fun.decl, scopes);
                const ret = funNode.ret.?;
                break :blk try getType(ret, scopes);
            };
            return getTypeRefFor(Type.Void);
        },
        .Add => |v| {
            const left = try getType(v.left, scopes);
            const right = try getType(v.right, scopes);
            return try typesEqual(left, right, v.left, v.right, ast);
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
            const tp = if (v.value) |val| try getType(val, scopes) else return getTypeRefFor(.{ .ArrayOf = try getTypeRefFor(Type.Never) });
            if (v.next) |next| {
                _ = try typesEqual(tp, try getType(next, scopes), v.value.?, next, ast);
            }
            return getTypeRefFor(.{ .ArrayOf = tp });
        },
        .ArrayLiteralContinuation => |v| {
            const value = if (v.value) |val| try getType(val, scopes) else return try getTypeRefFor(Type.Never);
            if (v.next) |next| {
                _ = try typesEqual(value, try getType(next, scopes), v.value.?, next, ast);
            }
            return value;
        },
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
                    return Err.errUnexpectedType(v.left, left, try getTypeRefFor(.{ .ArrayOf = try getTypeRefFor(Type.Any) }), null);
                },
            };
            return actualType;
        },
        .Statement => |v| {
            if (v.next) |next| {
                return getType(next, scopes);
            } else {
                return getType(v.ast, scopes);
            }
        },
        .Return => |v| {
            return getType(v.value, scopes);
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
                    return Err.ParseError.UnknownTypeToken;
                },
                else => unreachable,
            }
        },
        .TypeArrayOf => |v| {
            return getTypeRefFor(.{ .ArrayOf = try parseTypeExpression(v) });
        },
        else => unreachable,
    }
}

pub fn validateStatement(ast: Ast.AstRef, scopes: *scope.Scopes) Err.ParseError!void {
    switch (ast.getNode().*) {
        .Statement => |v| {
            _ = try typesEqualNoRight(try getType(v.ast, scopes), try getTypeRefFor(Type.Void), v.ast, ast);
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
