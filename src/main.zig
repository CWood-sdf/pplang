const std = @import("std");
const Pretty = @import("pretty.zig");
const lex = @import("lexer.zig");
const Ast = @import("ast.zig");
const Tp = @import("types.zig");

pub fn writeParamNames(ast: ?Ast.AstRef, writer: std.fs.File.Writer) !void {
    if (ast == null) return;
    switch (ast.?.getNode().*) {
        .FunctionParameterDecl => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try std.fmt.format(writer, "{s}", .{name});
            if (v.next) |next| {
                _ = try writer.write(", ");
                try writeParamNames(next, writer);
            }
        },
        else => unreachable,
    }
}

pub fn convertAst(ast: Ast.AstRef, writer: std.fs.File.Writer) !void {
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
            _ = try std.fmt.format(writer, "{s}", .{name});
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
                _ = try std.fmt.format(writer, "struct {s} {{\n", .{fnName});
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
                _ = try std.fmt.format(writer, "struct {s}<", .{fnName});
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
            _ = try std.fmt.format(writer, "typename {s}", .{name});
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
                    try std.fmt.format(writer, "{s} ", .{str});
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
                    try std.fmt.format(writer, "Int<{}> ", .{val});
                },
                else => unreachable,
            }
        },
        .Float => |v| {
            switch (v.tok) {
                .FloatLiteral => |val| {
                    try std.fmt.format(writer, "Float<{}> ", .{val});
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
                    try std.fmt.format(writer, "{s} ", .{str});
                },
                else => unreachable,
            }
        },
        .FunctionAccess => |v| {
            switch (v.name.tok) {
                .Ident => |str| {
                    try std.fmt.format(writer, "{s} ", .{str});
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

    _ = try file.write("#include \"stdlib.hpp\"\n");

    try convertAst(ast, file.writer());
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const file = try std.fs.cwd().openFile("lang._pp", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var inStream = reader.reader();

    var backingArr = std.ArrayList(u8).init(alloc);
    defer backingArr.deinit();
    while (true) {
        const size = 1024;
        const bytes = try inStream.readBoundedBytes(size);
        try backingArr.appendSlice(bytes.constSlice());
        if (bytes.len < size) {
            break;
        }
    }

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer().any();
    const bw = stdout_file;
    const stdout = bw;

    var lexer = lex.Lexer.init(backingArr.items);

    Ast.astNodes = @TypeOf(Ast.astNodes).init(alloc);
    defer Ast.astNodes.deinit();
    Ast.errorBus = @TypeOf(Ast.errorBus).init(alloc);
    defer Ast.errorBus.deinit();
    Ast.typeTree = @TypeOf(Ast.typeTree).init(alloc);
    defer Ast.typeTree.deinit();

    const node = Ast.parseAst(&lexer) catch {
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        return;
    };

    Tp.validateTypes(node.?, alloc) catch {
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        return;
    };
    // Pretty.printAst(node.?, 0);
    try writeAstToFile(node.?, "urmom.cpp");
    // while (!lexer.isEOF()) {
    //     try stdout.print("{}\n", .{lexer.getNextToken() catch unreachable});
    // }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
