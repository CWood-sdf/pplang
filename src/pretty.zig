const std = @import("std");
const Ast = @import("ast.zig");
const Lex = @import("lexer.zig");
pub fn printIndent(indent: u32) void {
    var ind = indent;
    while (ind > 0) {
        std.debug.print(" ", .{});
        ind -= 1;
    }
}

pub fn printAst(ref: Ast.AstRef, indent: u32) void {
    printIndent(indent);
    switch (ref.getNode().*) {
        .Statement => |node| {
            std.debug.print("Statement: \n", .{});
            printAst(node.ast, indent + 2);
            if (node.next) |next| {
                printAst(next, indent);
            }
        },
        .Declaration => |node| {
            std.debug.print("Declaration: \n", .{});
            printAst(node.name, indent + 2);
            if (node.tp) |tp| {
                printAst(tp, indent + 2);
            }
            printAst(node.value, indent + 2);
        },
        .Float => |node| {
            switch (node.tok) {
                .FloatLiteral => |v| {
                    std.debug.print("Float: {}\n", .{v});
                },
                else => unreachable,
            }
        },
        .Int => |node| {
            switch (node.tok) {
                .IntLiteral => |v| {
                    std.debug.print("Int: {}\n", .{v});
                },
                else => unreachable,
            }
        },
        .True => {
            std.debug.print("Bool: true\n", .{});
        },
        .False => {
            std.debug.print("Bool: false\n", .{});
        },
        .Ident => |node| {
            switch (node.tok) {
                .Ident => |v| {
                    std.debug.print("Ident: '{s}'\n", .{v});
                },
                else => unreachable,
            }
        },
        .String => |node| {
            std.debug.print("String: {}\n", .{node});
        },
        .RawType => |node| {
            switch (node.tok) {
                .Ident => |v| {
                    std.debug.print("RawType: '{s}'\n", .{v});
                },
                else => unreachable,
            }
        },
        .TypeArrayOf => |node| {
            std.debug.print("TypeArrayOf:\n", .{});
            printAst(node, indent + 2);
        },
        .Add => |node| {
            std.debug.print("Add:\n", .{});
            printAst(node.left, indent + 2);
            printAst(node.right, indent + 2);
        },
        .Sub => |node| {
            std.debug.print("Sub:\n", .{});
            printAst(node.left, indent + 2);
            printAst(node.right, indent + 2);
        },
        .Equals => |node| {
            std.debug.print("Equals:\n", .{});
            printAst(node.left, indent + 2);
            printAst(node.right, indent + 2);
        },
        .ArrayLiteral => |v| {
            std.debug.print("ArrayLiteral:\n", .{});
            if (v.value) |val| {
                printAst(val, indent + 2);
            }
            if (v.next) |next| {
                printAst(next, indent);
            }
        },
        .ArrayLiteralContinuation => |v| {
            std.debug.print("ArrayLiteralCont:\n", .{});
            if (v.value) |val| {
                printAst(val, indent + 2);
            }
            if (v.next) |next| {
                printAst(next, indent);
            }
        },
        .VariableAccess => |node| {
            switch (node.tok) {
                .Ident => |v| {
                    std.debug.print("VariableAccess: '{s}'\n", .{v});
                },
                else => unreachable,
            }
        },
        .FunctionAccess => |node| {
            switch (node.name.tok) {
                .Ident => |v| {
                    std.debug.print("FunctionAccess: '{s}'\n", .{v});
                },
                else => unreachable,
            }
        },
        .ArrayAccess => |node| {
            std.debug.print("ArrayAccess:\n", .{});
            printAst(node.left, indent + 2);
            printAst(node.right, indent + 2);
        },
        // .FunctionForwardDecl => |node| {
        //     std.debug.print("FunctionForwardDecl:\n", .{});
        //     if (node.params) |params| {
        //         printAst(params, indent + 2);
        //     }
        //     printIndent(indent + 2);
        //     std.debug.print("Return:\n", .{});
        //     printAst(node.ret, indent + 4);
        // },
        .FunctionDecl => |node| {
            std.debug.print("FunctionDecl:\n", .{});
            if (node.params) |params| {
                printAst(params, indent + 2);
            }
            if (node.where) |where| {
                printIndent(indent + 2);
                std.debug.print("Where: \n", .{});
                printAst(where, indent + 4);
            }
            printAst(node.block, indent + 2);
        },
        .FunctionParameterDecl => |node| {
            std.debug.print("Function Parameter:\n", .{});
            printIndent(indent + 2);
            std.debug.print("Name: ", .{});
            switch (node.name.tok) {
                .Ident => |str| std.debug.print("{s}\n", .{str}),
                else => unreachable,
            }
            printAst(node.tp, indent + 2);
            if (node.next) |next|
                printAst(next, indent);
        },
        .FunctionCall => |node| {
            std.debug.print("FunctionCall: \n", .{});
            printIndent(indent + 2);
            std.debug.print("Name: ", .{});
            switch (node.name.tok) {
                .Ident => |str| std.debug.print("{s}\n", .{str}),
                else => unreachable,
            }
            if (node.params) |params| {
                printAst(params, indent + 2);
            }
        },
        .FunctionCallParam => |p| {
            std.debug.print("FunctionCall: \n", .{});
            printAst(p.value, indent + 2);
            if (p.next) |next| {
                printAst(next, indent);
            }
        },
        .Return => |node| {
            std.debug.print("Return:\n", .{});
            printAst(node.value, indent + 2);
        },
        .FunctionType => |node| {
            std.debug.print("FunctionType:\n", .{});
            if (node.params) |params| {
                printAst(params, indent + 2);
            }
            printIndent(indent + 2);
            std.debug.print("Returns:\n", .{});
            printAst(node.ret, indent + 4);
        },
        .FunctionTypeParams => |node| {
            std.debug.print("Param:\n", .{});
            printAst(node.tp, indent + 2);
            if (node.next) |next| {
                printAst(next, indent);
            }
        },
        .TypeTupleOf => unreachable,
    }
}
