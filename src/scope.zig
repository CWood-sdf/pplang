const std = @import("std");
const Lex = @import("lexer.zig");
const Tp = @import("types.zig");
const Ast = @import("ast.zig");
const Err = @import("error.zig");
pub const Scope = struct {
    vars: std.StringHashMap(Var),
    functions: std.StringHashMap(Function),
    pub const Var = struct {
        tp: Tp.TypeRef,
        decl: Ast.AstRef,
    };

    pub const Function = struct {
        decl: Ast.AstRef,
    };
    pub fn init(alloc: std.mem.Allocator) Scope {
        return .{ .vars = std.StringHashMap(Var).init(alloc), .functions = std.StringHashMap(Function).init(alloc) };
    }
    pub fn deinit(self: *Scope) void {
        self.vars.deinit();
        self.functions.deinit();
    }
    pub fn getTypeFor(self: *Scope, str: []const u8) ?Tp.TypeRef {
        const val = self.vars.get(str);
        if (val) |v| {
            return v.tp;
        }
        return null;
    }

    pub fn setVar(self: *Scope, str: []const u8, tp: Tp.TypeRef, decl: Ast.AstRef) Err.ParseError!void {
        const res = self.vars.getOrPut(str) catch return Err.ParseError.OutOfMemory;
        if (res.found_existing) {
            return Err.errVariableRedecl(res.value_ptr.decl, decl);
        }
        res.value_ptr.* = .{
            .tp = tp,
            .decl = decl,
        };
    }
    pub fn setFunction(self: *Scope, str: []const u8, decl: Ast.AstRef) Err.ParseError!void {
        const res = self.functions.getOrPut(str) catch return Err.ParseError.OutOfMemory;
        if (res.found_existing) {
            return Err.errVariableRedecl(res.value_ptr.decl, decl);
        }
        res.value_ptr.* = .{
            .decl = decl,
        };
    }
    pub fn setFunctionNonDefault(self: *Scope, str: []const u8, name: Lex.Token) Err.ParseError!void {
        const res = self.functions.getOrPut(str) catch return Err.ParseError.OutOfMemory;
        if (!res.found_existing) {
            return Err.errVarNotExist(name);
        }
    }
    pub fn getFunctionDecl(self: *Scope, str: []const u8, name: Lex.Token) Err.ParseError!*Function {
        const res = self.functions.getOrPut(str) catch return Err.ParseError.OutOfMemory;
        if (!res.found_existing) {
            return Err.errVarNotExist(name);
        }
        return res.value_ptr;
    }
};

pub const Scopes = struct {
    scopes: std.ArrayList(Scope),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) Err.ParseError!Scopes {
        var ret = Scopes{ .scopes = std.ArrayList(Scope).init(alloc), .alloc = alloc };
        ret.scopes.append(Scope.init(alloc)) catch return Err.ParseError.OutOfMemory;
        return ret;
    }
    pub fn deinit(self: *Scopes) void {
        for (self.scopes.items) |*scope| {
            scope.deinit();
        }
        self.scopes.deinit();
    }
    pub fn addScope(self: *Scopes) Err.ParseError!void {
        self.scopes.append(Scope.init(self.alloc)) catch return Err.ParseError.OutOfMemory;
    }
    pub fn popScope(self: *Scopes) void {
        self.scopes.pop().deinit();
    }
    pub fn addVar(self: *Scopes, str: []const u8, tp: Tp.TypeRef, decl: Ast.AstRef) Err.ParseError!void {
        const last = &self.scopes.items[self.scopes.items.len - 1];
        try last.setVar(str, tp, decl);
    }
    pub fn getVar(self: *Scopes, str: []const u8, node: Lex.Token) Err.ParseError!Tp.TypeRef {
        var i: usize = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            if (self.scopes.items[i].getTypeFor(str)) |tp| {
                return tp;
            }
            _ = Ast.errorBus.pop();
        }
        return Err.errVarNotExist(node);
    }

    pub fn addDefaultFunction(self: *Scopes, str: []const u8, decl: Ast.AstRef) Err.ParseError!void {
        const last = &self.scopes.items[self.scopes.items.len - 1];
        try last.setFunction(str, decl);
    }
    pub fn addFunction(self: *Scopes, str: []const u8, decl: Lex.Token) Err.ParseError!void {
        const last = &self.scopes.items[self.scopes.items.len - 1];
        try last.setFunctionNonDefault(str, decl);
    }
    pub fn getFunction(self: *Scopes, str: []const u8, name: Lex.Token) Err.ParseError!*Scope.Function {
        var i: usize = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            if (self.scopes.items[i].getFunctionDecl(str)) |tp| {
                return tp;
            }
            _ = Ast.errorBus.pop();
        }
        return Err.errVarNotExist(name);
    }
};
