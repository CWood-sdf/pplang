const std = @import("std");
const Pretty = @import("pretty.zig");
const lex = @import("lexer.zig");
const Ast = @import("ast.zig");

const errorSet = std.Io.Writer.Error;

const Settings = struct {
    importPrelude: bool = true,
    importStdlib: bool = false,
    instantiate: bool = true,
    includeMain: bool = true,
};

var settings: Settings = .{};

pub fn writeParamNames(ast: ?Ast.AstRef, writer: *std.Io.Writer) errorSet!void {
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
        .FunctionParameterPackDecl => |v| {
            const name = v.name.tok.Ident;
            _ = try writer.print("{s}... ", .{name});
        },
        .FunctionArrayParam => |v| {
            _ = try writer.write("Array<");
            try writeParamNames(v.params, writer);
            _ = try writer.write(">");
            if (v.next) |next| {
                _ = try writer.write(", ");
                try writeParamNames(next, writer);
            }
        },
        else => {
            std.debug.print("{}\n", .{ast.?.getNode().*});
            unreachable;
        },
    }
}

// pub fn writeFunctionParameterNamesFor(ast: Ast.AstRef, writer: *std.Io.Writer) errorSet!void {
//     switch (ast.getNode().*) {
//         .FunctionType => |f| {
//             if (f.params == null) {
//                 return;
//             }
//             _ = try writer.write("<");
//             var param = f.params;
//             var i: u16 = 0;
//             while (param) |p| {
//                 _ = try writer.print("__param__{}", .{i});
//                 i += 1;
//                 switch (p.getNode().*) {
//                     .FunctionTypeParams => |idk| {
//                         param = idk.next;
//                     },
//                     else => unreachable,
//                 }
//                 if (param != null) {
//                     _ = try writer.write(", ");
//                 }
//             }
//             _ = try writer.write(">");
//         },
//         else => {
//             std.debug.print("{}\n", .{ast.getNode().*});
//             // unreachable;
//         },
//     }
// }

pub fn convertAst(
    ast: Ast.AstRef,
    writer: *std.Io.Writer,
    currentReturnTp: ?Ast.AstRef,
    // typenameIndex: i16,
) errorSet!void {
    switch (ast.getNode().*) {
        .FunctionArrayParam => |v| {
            try convertAst(v.params, writer, currentReturnTp);
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer, currentReturnTp);
            }
        },
        .FunctionCallParam => |v| {
            try convertAst(v.value, writer, currentReturnTp);
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer, currentReturnTp);
            }
        },
        .FunctionType => |_| {
            // _ = try writer.write("template<");
            // if (v.params) |params| {
            //     try convertAst(params, writer, currentReturnTp);
            // }
            // _ = try writer.write("> ");
            // if (typenameIndex == -1) {
            _ = try writer.write("typename ");
            // } else {
            //     _ = try writer.print("typename __param__{} ", .{typenameIndex});
            // }
        },
        .FunctionTypeParams => |v| {
            try convertAst(v.tp, writer, currentReturnTp);
            if (v.next) |next| {
                _ = try writer.write(", ");
                // const nextIndex = if (typenameIndex != -1)
                //     typenameIndex + 1
                // else
                //     -1;
                try convertAst(next, writer, currentReturnTp);
            }
        },
        .TypeArrayOf => {
            _ = try writer.write("typename ");
            // if (typenameIndex != -1) {
            //     _ = try writer.print("__param__{} ", .{typenameIndex});
            // }
        },
        .TypeTupleOf => unreachable,
        .String => unreachable,
        .RawType => |_| {
            _ = try writer.write("typename ");
            // if (typenameIndex != -1) {
            //     _ = try writer.print("__param__{} ", .{typenameIndex});
            // }
        },
        .FunctionParameterPackDecl => |v| {
            _ = try writer.print("typename... {s} ", .{v.name.tok.Ident});
        },
        .FunctionParameterDecl => |v| {
            try convertAst(v.tp, writer, currentReturnTp);
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try writer.print("{s}", .{name});
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer, currentReturnTp);
            }
        },
        .FunctionDecl => |v| {
            if (v.params) |params| {
                _ = try writer.write("template<");
                try convertAst(params, writer, currentReturnTp);
                _ = try writer.write(">\n");
            }
            const fnName = switch (v.name.getNode().*) {
                .Ident => |n| switch (n.tok) {
                    .Ident => |str| str,
                    else => unreachable,
                },
                else => unreachable,
            };
            if (v.ret) |_| {
                _ = try writer.print("struct {s}__actual {{\n", .{fnName});
            } else if (v.where) |where| {
                _ = try writer.write("requires (GetValue<");
                try convertAst(where, writer, currentReturnTp);
                _ = try writer.write(">::val)\n");
                _ = try writer.print("struct {s}__actual<", .{fnName});
                try writeParamNames(v.params, writer);
                _ = try writer.write(">{\n");
            } else unreachable;

            try convertAst(v.block, writer, v.ret);
            _ = try writer.write("};\n\n");

            if (v.ret) |_| {
                _ = try writer.print("struct {s} {{\n\n", .{fnName});

                if (v.params) |yo| {
                    _ = try writer.write("template<");
                    try printUsingParamsFor(yo, writer);
                    _ = try writer.write("> ");
                }
                _ = try writer.print("using __apply = {s}__actual ", .{fnName});
                if (v.params) |params| {
                    _ = try writer.write("<");
                    try writeParamNames(params, writer);
                    _ = try writer.write(">");
                }

                _ = try writer.write(";\n};\n\n");
            }
        },
        .FunctionCall => |v| {
            const name = switch (v.name.tok) {
                .Ident => |str| str,
                else => unreachable,
            };
            _ = try writer.print("typename {s}", .{name});
            if (v.params) |params| {
                _ = try writer.write("::template __apply<");
                try convertAst(params, writer, currentReturnTp);
                _ = try writer.write(">");
            } else {
                _ = try writer.write("::__apply");
            }
            _ = try writer.write("::__ret ");
        },
        .Statement => |v| {
            try convertAst(v.ast, writer, currentReturnTp);
            if (v.next) |next| {
                try convertAst(next, writer, currentReturnTp);
            }
        },
        .Declaration => |v| {
            // const tp = v.tp;
            // if (tp) |t| {
            //     switch (t.getNode().*) {
            //         .FunctionType => {
            //             try printUsingParamsFor(t, writer);
            //         },
            //         else => {},
            //     }
            // }
            _ = try writer.write("using ");
            try convertAst(v.name, writer, currentReturnTp);
            _ = try writer.write(" = ");
            try convertAst(v.value, writer, currentReturnTp);
            // if (tp) |t| {
            //     try writeFunctionParameterNamesFor(t, writer);
            // }
            _ = try writer.write(";\n\n");

            if (settings.instantiate) {
                try convertAst(v.name, writer, currentReturnTp);
                _ = try writer.write(" _____INSTANCE_OF_");
                try convertAst(v.name, writer, currentReturnTp);
                _ = try writer.write(";\n\n");
            }
            // try convertAst(v.value, writer, currentReturnTp);
            // if (tp) |t| {
            //     try writeFunctionParameterNamesFor(t, writer);
            // }
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
        .Char => |v| {
            try writer.print("Char<{}> ", .{v.tok.CharLiteral});
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
                    try writer.print("Float<(double){}> ", .{val});
                },
                else => unreachable,
            }
        },
        .Add => |v| {
            _ = try writer.write("typename Add<");
            try convertAst(v.left, writer, currentReturnTp);
            _ = try writer.write(", ");
            try convertAst(v.right, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .Equals => |v| {
            _ = try writer.write("typename Equals<");
            try convertAst(v.left, writer, currentReturnTp);
            _ = try writer.write(", ");
            try convertAst(v.right, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .Sub => |v| {
            _ = try writer.write("typename Sub<");
            try convertAst(v.left, writer, currentReturnTp);
            _ = try writer.write(", ");
            try convertAst(v.right, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .Merge => |v| {
            _ = try writer.write("typename Merge<");
            try convertAst(v.left, writer, currentReturnTp);
            _ = try writer.write(", ");
            try convertAst(v.right, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .Sizeof => |v| {
            _ = try writer.write("typename Sizeof<");
            try convertAst(v.value, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .ArrayLiteral => |v| {
            _ = try writer.write("Array<");
            if (v.value) |val| {
                try convertAst(val, writer, currentReturnTp);
                if (v.next) |next| {
                    _ = try writer.write(", ");
                    try convertAst(next, writer, currentReturnTp);
                }
            }
            _ = try writer.write(">");
        },
        .ArrayLiteralContinuation => |v| {
            if (v.value) |val| {
                try convertAst(val, writer, currentReturnTp);
            } else unreachable;
            if (v.next) |next| {
                _ = try writer.write(", ");
                try convertAst(next, writer, currentReturnTp);
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

        .EllipsisAccess => |v| {
            _ = try writer.print("{s}... ", .{v.name.tok.Ident});
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
            try convertAst(v.left, writer, currentReturnTp);
            _ = try writer.write(", ");
            try convertAst(v.right, writer, currentReturnTp);
            _ = try writer.write(">::__ret ");
        },
        .Return => |v| {
            // if (currentReturnTp) |c| {
            //     try printUsingParamsFor(c, writer);
            // }
            _ = try writer.write("using __ret = ");
            try convertAst(v.value, writer, currentReturnTp);
            // if (currentReturnTp) |c| {
            //     try writeFunctionParameterNamesFor(c, writer);
            // }
            _ = try writer.write(";\n\n");

            if (settings.instantiate) {
                _ = try writer.write("__ret __INSTANCE_OF_ret;\n\n");
            }
        },
    }
}

fn printUsingParamsFor(ast: Ast.AstRef, writer: *std.Io.Writer) errorSet!void {
    switch (ast.getNode().*) {
        .FunctionParameterDecl => |_| {
            var param: ?Ast.AstRef = ast;
            var i: u16 = 0;
            while (param) |p| {
                switch (p.getNode().*) {
                    .FunctionParameterDecl => |f| {
                        _ = try writer.print("typename {s}", .{f.name.tok.Ident});
                        i += 1;
                        param = f.next;
                        if (param != null) {
                            _ = try writer.write(",");
                        }
                    },
                    else => unreachable,
                }
            }
        },
        .FunctionParameterPackDecl => |f| {
            _ = try writer.print("typename... {s}", .{f.name.tok.Ident});
        },
        .FunctionType => |f| {
            if (f.params == null) {
                return;
            }
            _ = try writer.write("template <");
            var param = f.params;
            var i: u16 = 0;
            while (param) |p| {
                switch (p.getNode().*) {
                    .FunctionTypeParams => |idk| {
                        try convertAst(idk.tp, writer, null);
                        _ = try writer.print(" __param__{} ", .{i});
                        i += 1;
                        param = idk.next;
                        if (param != null) {
                            _ = try writer.write(",");
                        }
                    },
                    else => unreachable,
                }
            }
            _ = try writer.write("> \n");
        },
        else => {},
    }
}

pub fn writeAstToFile(ast: Ast.AstRef, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    // const file = try std.fs.cwd().openFile(filename, .{ .mode = .write_only });

    var buf: [1024]u8 = undefined;
    var w = file.writer(&buf);
    const iow = &w.interface;
    if (settings.importPrelude) {
        _ = try iow.write("#include \"prelude.hpp\"\n\n");
    }
    if (settings.importStdlib) {
        _ = try iow.write("#include \"stdlib.hpp\"\n\n");
    }

    try convertAst(ast, iow, null);
    if (settings.includeMain) {
        _ = try iow.write("\n\nint main(){}");
    }

    try iow.flush();
}

pub fn parseFile(alloc: std.mem.Allocator, input: []const u8, output: []const u8) !void {
    const file = try std.fs.cwd().openFile(input, .{});
    defer file.close();

    var buf: [1028]u8 = undefined;

    var reader = file.reader(&buf);
    const inStream = &reader.interface;

    var backingArr: std.ArrayList(u8) = .empty;
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
    // Ast.typeTree = @TypeOf(Ast.typeTree).empty;
    // defer Ast.typeTree.deinit(alloc);

    const node = Ast.parseAst(&lexer) catch {
        for (Ast.errorBus.items) |err| {
            try err.prettyPrint(stdout, &lexer);
        }
        std.debug.print("Got {} errors\n", .{Ast.errorBus.items.len});
        try stdout.flush();
        return;
    };

    try writeAstToFile(node.?, output);
    try stdout.flush();
}

fn determineInOut(iter: *std.process.ArgIterator, in: *?[]const u8, out: *?[]const u8) void {
    var expectingIn: bool = false;
    var expectingOut: bool = false;

    var settingFalse: bool = false;
    var settingTrue: bool = false;
    while (iter.next()) |i| {
        if (expectingIn) {
            in.* = i;
            expectingIn = false;
        } else if (expectingOut) {
            out.* = i;
            expectingOut = false;
        } else if (settingFalse) {
            inline for (@typeInfo(Settings).@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, i)) {
                    @field(settings, field.name) = false;
                    break;
                }
            }
            settingFalse = false;
        } else if (settingTrue) {
            inline for (@typeInfo(Settings).@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, i)) {
                    @field(settings, field.name) = true;
                    break;
                }
            }
            settingFalse = true;
        }
        if (std.mem.eql(u8, "-i", i)) {
            expectingIn = true;
        } else if (std.mem.eql(u8, "-o", i)) {
            expectingOut = true;
        } else if (std.mem.eql(u8, "-yes", i)) {
            settingTrue = true;
        } else if (std.mem.eql(u8, "-no", i)) {
            settingFalse = true;
        }
    }
    in.* = in.* orelse "lang._pp";
    out.* = out.* orelse "urmom.cpp";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var argIter = std.process.args();

    var input: ?[]const u8 = null;
    var output: ?[]const u8 = null;

    determineInOut(&argIter, &input, &output);

    const alloc = gpa.allocator();
    std.debug.print("PP {s} -> {s}\n", .{ input.?, output.? });
    try parseFile(alloc, input.?, output.?);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
