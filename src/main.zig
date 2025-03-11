const std = @import("std");
const Pretty = @import("pretty.zig");
const lex = @import("lexer.zig");
const Ast = @import("ast.zig");
const Tp = @import("types.zig");

pub fn convertAst(ast: Ast.AstRef, writer: std.fs.File.Writer) !void {
    switch (ast.getNode().*) {
        .FunctionDecl => {},
        .Statement => |v| {
            try convertAst(v.ast, writer);
            if (v.next) |next| {
                try convertAst(next, writer);
            }
        },
        .Declaration => |v| {
            _ = try writer.write("typedef ");
            try convertAst(v.value, writer);
            try convertAst(v.name, writer);
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
        .Int => |v| {
            switch (v.tok) {
                .IntLiteral => |val| {
                    try std.fmt.format(writer, "Int<{}> ", .{val});
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
        .ArrayAccess => |v| {
            _ = try writer.write("typename Index<");
            try convertAst(v.left, writer);
            _ = try writer.write(", ");
            try convertAst(v.right, writer);
            _ = try writer.write(">::__ret ");
        },
        else => unreachable,
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

    var buf: [1024]u8 = undefined;

    var backingArr = std.ArrayList(u8).init(alloc);
    defer backingArr.deinit();

    while (try inStream.readUntilDelimiterOrEof(&buf, 0)) |line| {
        try backingArr.appendSlice(line);
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

    const node = Ast.parseAst(&lexer) catch |e| {
        std.debug.print("oops {}\n", .{e});
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        return;
    };

    Tp.validateTypes(node.?, alloc) catch |e| {
        std.debug.print("oops {}\n", .{e});
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        return;
    };
    try writeAstToFile(node.?, "urmom.cpp");
    Pretty.printAst(node.?, 0);
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
