const std = @import("std");
const Pretty = @import("pretty.zig");
const lex = @import("lexer.zig");
const Ast = @import("ast.zig");
const Tp = @import("types.zig");

pub fn writeParamNames(ast: ?Ast.AstRef, writer: *std.Io.Writer) !void {
    if (ast == null) return;
    switch (ast.?.getNode().*) {
        .FunctionParameterDecl => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try writer.print("{s}", .{name});
            if (v.next) |next| {
                _ = try writer.write(", ");
                try writeParamNames(next, writer);
            }
        },
        else => unreachable,
    }
}

pub fn convertAst(ast: Ast.AstRef, writer: *std.Io.Writer) !void {
    switch (ast.getNode().*) {
        .FunctionCallParam => |v| {
            try convertAst(v.value, writer);
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer);
            }
        },
        .FunctionType => |v| {
            _ = try writer.write("template<");
            if (v.params) |params| {
                try convertAst(params, writer);
            }
            _ = try writer.write("> typename ");
        },
        .FunctionTypeParams => |v| {
            try convertAst(v.tp, writer);
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer);
            }
        },
        .TypeArrayOf => {
            _ = try writer.write("typename ");
        },
        .TypeTupleOf => unreachable,
        .String => unreachable,
        .RawType => |_| {
            _ = try writer.write("typename ");
        },
        .FunctionParameterDecl => |v| {
            try convertAst(v.tp, writer);
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try writer.print("{s}", .{name});
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer);
            }
        },
        .FunctionDecl => |v| {
            if (v.params) |params| {
                _ = try writer.write("template<");
                try convertAst(params, writer);
                _ = try writer.write(">\n");
            }
            if (v.ret) |_| {
                const fnName = switch (v.name.getNode().*) {
                    .Ident => |n| switch (n.tok) {
                        .Ident => |str| str,
                        else => unreachable,
                    },
                    else => unreachable,
                };
                _ = try writer.print("struct {s} {{\n", .{fnName});
                try convertAst(v.block, writer);
                _ = try writer.write("};\n");
            } else {
                if (v.where) |where| {
                    _ = try writer.write("requires (GetValue<");
                    try convertAst(where, writer);
                    _ = try writer.write(">::val)\n");
                } else unreachable;
                const fnName = switch (v.name.getNode().*) {
                    .Ident => |n| switch (n.tok) {
                        .Ident => |str| str,
                        else => unreachable,
                    },
                    else => unreachable,
                };
                _ = try writer.print("struct {s}<", .{fnName});
                try writeParamNames(v.params, writer);
                _ = try writer.write(">{\n");
                try convertAst(v.block, writer);
                _ = try writer.write("};\n");
            }
        },
        .FunctionCall => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try writer.print("typename {s}", .{name});
            if (v.params) |params| {
                _ = try writer.write("<");
                try convertAst(params, writer);
                _ = try writer.write(">");
            }
            _ = try writer.write("::__ret ");
        },
        .Statement => |v| {
            try convertAst(v.ast, writer);
            if (v.next) |next| {
                try convertAst(next, writer);
            }
        },
        .Declaration => |v| {
            _ = try writer.write("using ");
            try convertAst(v.name, writer);
            _ = try writer.write(" = ");
            try convertAst(v.value, writer);
            _ = try writer.write(";\n");
        },
        .Ident => |v| {
            switch (v.tok) {
                .Ident => |str| {
                    try writer.print("{s} ", .{str});
                },
                else => unreachable,
            }
        },
        .True => {
            _ = try writer.write("Bool<true>");
        },
        .False => {
            _ = try writer.write("Bool<false>");
        },
        .Int => |v| {
            switch (v.tok) {
                .IntLiteral => |val| {
                    try writer.print("Int<{}> ", .{val});
                },
                else => unreachable,
            }
        },
        .Float => |v| {
            switch (v.tok) {
                .FloatLiteral => |val| {
                    try writer.print("Float<{}> ", .{val});
                },
                else => unreachable,
            }
        },
        .Add => |v| {
            _ = try writer.write("typename Add<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        .Equals => |v| {
            _ = try writer.write("typename Equals<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        .Sub => |v| {
            _ = try writer.write("typename Sub<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        .Merge => |v| {
            _ = try writer.write("typename Merge<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        .Sizeof => |v| {
            _ = try writer.write("typename Sizeof<");
            try convertAst(v.value, writer);
            _ = try writer.write(">::__ret ");
        },
        .ArrayLiteral => |v| {
            _ = try writer.write("Array<");
            if (v.value) |val| {
                try convertAst(val, writer);
                if (v.next) |next| {
                    _ = try writer.write(", ");
                    try convertAst(next, writer);
                }
            }
            _ = try writer.write(">");
        },
        .ArrayLiteralContinuation => |v| {
            if (v.value) |val| {
                try convertAst(val, writer);
            } else unreachable;
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer);
            }
        },
        .VariableAccess => |v| {
            switch (v.tok) {
                .Ident => |str| {
                    try writer.print("{s} ", .{str});
                },
                else => unreachable,
            }
        },
        .FunctionAccess => |v| {
            switch (v.name.tok) {
                .Ident => |str| {
                    try writer.print("{s} ", .{str});
                },
                else => unreachable,
            }
        },
        .ArrayAccess => |v| {
            _ = try writer.write("typename Index<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        .Return => |v| {
            _ = try writer.write("using __ret = ");
            try convertAst(v.value, writer);
            _ = try writer.write(";\n");
        },
    }
}

pub fn writeAstToFile(ast: Ast.AstRef, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    // const file = try std.fs.cwd().openFile(filename, .{ .mode = .write_only });

    var buf: [1024]u8 = undefined;
    var w = file.writer(&buf);
    const iow = &w.interface;
    _ = try iow.write("#include \"stdlib.hpp\"\n");

    try convertAst(ast, iow);

    try iow.flush();
}

pub fn main() !void {
    // const v: u8 = 0;
    // @atomicRmw(u8, &v, std.builtin.AtomicRmwOp.Add, 1, std.builtin.AtomicOrder.release);
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const file = try std.fs.cwd().openFile("lang._pp", .{});
    defer file.close();

    var buf: [1028]u8 = undefined;

    var reader = file.reader(&buf);
    const inStream = &reader.interface;

    var backingArr: std.ArrayList(u8) = .empty;
    // backingArr.init(alloc);
    defer backingArr.deinit(alloc);
    while (true) {
        const size = 1024;
        var bytes: [size]u8 = undefined;
        const readBytes = try inStream.readSliceShort(&bytes);
        // const bytes = try inStream.readBoundedBytes(size);
        try backingArr.appendSlice(alloc, bytes[0..readBytes]);
        if (readBytes < size) {
            break;
        }
    }

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.

    var stdoutbuf: [1028]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdoutbuf);
    const stdout = &stdout_file.interface;

    var lexer = lex.Lexer.init(backingArr.items);

    Ast.alloc = alloc;
    Ast.astNodes = @TypeOf(Ast.astNodes).empty;
    defer Ast.astNodes.deinit(alloc);
    Ast.errorBus = @TypeOf(Ast.errorBus).empty;
    defer Ast.errorBus.deinit(alloc);
    Ast.typeTree = @TypeOf(Ast.typeTree).empty;
    defer Ast.typeTree.deinit(alloc);

    const node = Ast.parseAst(&lexer) catch {
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        return;
    };

    // Tp.validateTypes(node.?, alloc) catch {
    //     for (Ast.errorBus.items) |err| {
    //         try err.prettyPrint(stdout, &lexer);
    //     }
    //     return;
    // };
    // Pretty.printAst(node.?, 0);
    try writeAstToFile(node.?, "urmom.cpp");
    // while (!lexer.isEOF()) {
    //     try stdout.print("{}\n", .{lexer.getNextToken() catch unreachable});
    // }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try stdout.flush();

    // try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
