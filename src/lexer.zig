const std = @import("std");
pub const LexerError = error{
    InvalidLiteral,
    UnclosedString,
};
pub const TokenType = union(enum) {
    Ident: []const u8,
    EOF,

    // Braces
    LeftSqBracket,
    RightSqBracket,
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,

    // Symbols
    Comma,
    Colon,
    OpEq,
    OpEqEq,
    OpPls,
    OpMns,
    OpDiv,
    Arrow,
    Semicolon,

    // Literals
    StringLiteral: []const u8,
    CharLiteral: u8,
    IntLiteral: i64,
    FloatLiteral: f64,

    Comment: []const u8,

    // Reserved Words
    True,
    False,
    Let,
    Fn,
    Trait,
    Where,
    Return,
};

pub const Token = struct {
    endPos: usize,
    startPos: usize,
    // row: usize,
    // col: usize,
    tok: TokenType,

    pub fn init(lex: *Lexer, tok: TokenType) Token {
        return .{ .endPos = lex.pos, .startPos = lex.startPos, .tok = tok };
    }
};

pub const Lexer = struct {
    str: []u8,
    pos: usize,
    startPos: usize,
    row: usize,
    col: usize,
    startCol: usize,
    currentTok: ?Token,

    pub fn init(str: []u8) Lexer {
        return .{ .str = str, .pos = 0, .startPos = 0, .row = 0, .startCol = 0, .col = 0, .currentTok = null };
    }

    pub fn getLineFor(self: *const Lexer, pos: usize) usize {
        var line: usize = 1;
        for (self.str, 0..) |c, i| {
            if (i >= pos) {
                break;
            }
            if (c == '\n') {
                line += 1;
            }
        }
        return line;
    }
    pub fn getLine(self: *const Lexer, line: usize) []const u8 {
        var currentLine: usize = 1;
        var startPos: isize = -1;
        var endPos: usize = 0;
        for (self.str, 0..) |c, i| {
            if (currentLine == line and startPos < 0) {
                startPos = i;
            }
            if (c == '\n') {
                currentLine += 1;
            }
            if (currentLine > line) {
                endPos = i;
            }
        }
        return self.str[startPos..endPos];
    }
    pub fn makeToken(self: *Lexer, tok: TokenType) Token {
        return Token.init(self, tok);
    }
    pub fn makeTokenEatChar(self: *Lexer, tok: TokenType) Token {
        _ = self.eatChar();
        return Token.init(self, tok);
    }

    pub inline fn char(self: *Lexer) u8 {
        if (self.pos >= self.str.len) {
            return 0;
        }
        return self.str[self.pos];
    }
    pub inline fn peekChar(self: *Lexer) u8 {
        if (self.pos + 1 >= self.str.len) {
            return 0;
        }
        return self.str[self.pos + 1];
    }

    pub fn isAlpha(self: *Lexer) bool {
        const c = self.char();
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }
    pub fn isNum(self: *Lexer) bool {
        const c = self.char();
        return c >= '0' and c <= '9';
    }
    pub fn isHex(self: *Lexer) bool {
        const c = self.char();
        return self.isNum() or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
    }
    pub fn isOct(self: *Lexer) bool {
        const c = self.char();
        return c >= '0' and c <= '7';
    }
    pub fn isBin(self: *Lexer) bool {
        const c = self.char();
        return c == '0' or c == '1';
    }

    pub fn eatChar(self: *Lexer) u8 {
        if (self.pos >= self.str.len) {
            return 0;
        }
        const ret = self.str[self.pos];
        self.pos += 1;
        self.col += 1;
        if (self.pos >= 1 and self.pos < self.str.len and self.str[self.pos] == '\n') {
            self.row += 1;
            self.col = 0;
        }
        return ret;
    }

    pub fn readIdent(self: *Lexer) Token {
        const start = self.pos;
        while (self.isAlpha() or self.isNum()) {
            _ = self.eatChar();
        }
        const slice = self.str[start..self.pos];
        if (std.mem.eql(u8, slice, "let")) {
            return self.makeToken(TokenType.Let);
        }
        if (std.mem.eql(u8, slice, "fn")) {
            return self.makeToken(TokenType.Fn);
        }
        if (std.mem.eql(u8, slice, "trait")) {
            return self.makeToken(TokenType.Trait);
        }
        if (std.mem.eql(u8, slice, "where")) {
            return self.makeToken(TokenType.Where);
        }
        if (std.mem.eql(u8, slice, "return")) {
            return self.makeToken(TokenType.Return);
        }
        if (std.mem.eql(u8, slice, "true")) {
            return self.makeToken(TokenType.True);
        }
        if (std.mem.eql(u8, slice, "false")) {
            return self.makeToken(TokenType.False);
        }
        return self.makeToken(.{ .Ident = slice });
    }

    pub fn readOp(self: *Lexer) Token {
        switch (self.eatChar()) {
            '=' => {
                if (self.char() == '=') {
                    _ = self.eatChar();
                    return self.makeToken(TokenType.OpEqEq);
                }
                return self.makeToken(TokenType.OpEq);
            },
            '+' => {
                return self.makeToken(TokenType.OpPls);
            },
            '-' => {
                if (self.char() == '>') {
                    _ = self.eatChar();
                    return self.makeToken(TokenType.Arrow);
                }
                return self.makeToken(TokenType.OpMns);
            },
            '/' => {
                if (self.char() == '/') {
                    _ = self.eatChar();
                    const start = self.pos;
                    while (self.char() != '\n' and self.char() != 0) {
                        _ = self.eatChar();
                    }
                    return self.makeToken(.{ .Comment = self.str[start..self.pos] });
                }
                return self.makeToken(TokenType.OpDiv);
            },
            else => unreachable,
        }
    }

    pub fn isEOF(self: *Lexer) bool {
        if (self.currentTok) |tok| {
            return tok.tok == TokenType.EOF;
        }
        return false;
    }

    pub fn hexToNum(c: u8) u8 {
        if (c >= '0' and c <= '9') {
            return c - '0';
        }
        if (c >= 'a' and c <= 'f') {
            return c - 'a' + 10;
        }
        return c - 'A' + 10;
    }

    pub fn parseHex(self: *Lexer) i64 {
        _ = self.eatChar();
        var ret: i64 = 0;
        while (self.isHex()) {
            ret <<= 4;
            ret += Lexer.hexToNum(self.eatChar());
        }
        return ret;
    }
    pub fn parseOct(self: *Lexer) i64 {
        _ = self.eatChar();
        var ret: i64 = 0;
        while (self.isOct()) {
            ret <<= 3;
            ret += self.eatChar() - '0';
        }
        return ret;
    }
    pub fn parseBin(self: *Lexer) i64 {
        _ = self.eatChar();
        var ret: i64 = 0;
        while (self.isBin()) {
            ret <<= 1;
            ret += self.eatChar() - '0';
        }
        return ret;
    }

    pub fn readSpecialInt(self: *Lexer) LexerError!Token {
        return switch (self.peekChar()) {
            'x' => self.makeToken(.{ .IntLiteral = self.parseHex() }),
            'o' => self.makeToken(.{ .IntLiteral = self.parseOct() }),
            'b' => self.makeToken(.{ .IntLiteral = self.parseBin() }),
            'a', 'c'...'o' - 1, 'p'...'x' - 1, 'y', 'z', 'A'...'Z', '_' => LexerError.InvalidLiteral,
            else => self.makeToken(.{ .IntLiteral = 0 }),
        };
    }

    pub fn readNum(self: *Lexer) LexerError!Token {
        if (self.char() == '0') {
            _ = self.eatChar();
            return self.readSpecialInt();
        }
        var integer: i64 = 0;
        var decimal: f64 = 0;
        var decimalPower: f64 = 0.1;
        var isFloat = false;

        while (self.isNum() or self.char() == '.') {
            if (self.char() == '.') {
                if (isFloat) {
                    break;
                }
                isFloat = true;
            } else if (isFloat) {
                decimal += @as(f64, @floatFromInt(self.char() - '0')) * decimal;
                decimalPower *= 0.1;
            } else {
                integer *= 10;
                integer += self.char() - '0';
            }
            _ = self.eatChar();
        }
        if (isFloat) {
            return self.makeToken(.{ .FloatLiteral = @as(f64, @floatFromInt(integer)) + decimal });
        }
        return self.makeToken(.{ .IntLiteral = integer });
    }

    pub fn readString(self: *Lexer) LexerError!Token {
        _ = self.eatChar();
        const start = self.pos;
        while (self.eatChar() != '"') {
            if (self.char() == '\n' or self.char() == 0) {
                return LexerError.UnclosedString;
            }
        }
        return self.makeToken(.{ .StringLiteral = self.str[start..self.pos] });
    }

    pub fn getNextToken(self: *Lexer) LexerError!Token {
        if (self.pos >= self.str.len) {
            self.currentTok =
                self.makeToken(TokenType.EOF);
            return self.currentTok.?;
        }
        self.startCol = self.col;
        self.startPos = self.pos;
        while (self.char() <= 32 and self.char() > 0) {
            _ = self.eatChar();
        }
        self.currentTok = switch (self.char()) {
            'a'...'z', 'A'...'Z', '_' => self.readIdent(),
            ':' => self.makeTokenEatChar(TokenType.Colon),
            '[' => self.makeTokenEatChar(TokenType.LeftSqBracket),
            ']' => self.makeTokenEatChar(TokenType.RightSqBracket),
            '(' => self.makeTokenEatChar(TokenType.LeftParen),
            ')' => self.makeTokenEatChar(TokenType.RightParen),
            '{' => self.makeTokenEatChar(TokenType.LeftBrace),
            '}' => self.makeTokenEatChar(TokenType.RightBrace),
            ',' => self.makeTokenEatChar(TokenType.Comma),
            ';' => self.makeTokenEatChar(TokenType.Semicolon),
            '"' => try self.readString(),
            '=', '+', '-', '/' => self.readOp(),
            '0'...'9' => try self.readNum(),
            0 => self.makeToken(TokenType.EOF),

            else => |ch| blk: {
                std.debug.print("Failing at: (value {0}) (char {0c})\n", .{ch});
                break :blk self.makeToken(TokenType.EOF);
                // unreachable;
            },
        };
        return self.currentTok.?;
    }
    pub fn peekNextToken(self: *Lexer) Token {
        const startCol = self.startCol;
        const col = self.col;
        const tok = self.currentTok;
        const pos = self.pos;
        const row = self.row;
        defer self.startCol = startCol;
        defer self.col = col;
        defer self.currentTok = tok;
        defer self.pos = pos;
        defer self.row = row;

        return self.getNextToken() catch self.makeToken(TokenType.EOF);
    }
};
