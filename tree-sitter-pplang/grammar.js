module.exports = grammar({
    name: "pplang",
    word: ($) => $.identifier,
    extras: ($) => [/\s*/, $.comment],

    rules: {
        // TODO: add the actual grammar rules
        source_file: ($) => repeat($._statement),
        comment: (_) => seq("//", /[^\n]*/),
        _definition: ($) =>
            choice($.function_definition, $.variable_definition),
        fn: (_) => "fn",
        let: (_) => "let",
        arrow: (_) => "->",
        function_definition: ($) =>
            seq(
                $.fn,
                field("function_name", $.identifier),
                $.parameter_list,
                choice($.where_clause, seq($.arrow, $.type)),
                $.block,
            ),

        where_clause: ($) => seq("where", $.expression),

        raw_type: ($) => $.identifier,
        type: ($) =>
            choice(
                seq("[", $.type, "]"),
                $.raw_type,
                seq($.fn, $.parameter_list, $.arrow, $.type),
            ),

        variable_definition: ($) =>
            seq(
                $.let,
                field("name", $.identifier),
                optional(seq(":", $.type)),
                seq("=", field("right", $.expression)),
                ";",
            ),

        parameter_list: ($) =>
            seq(
                "(",
                optional(
                    seq(
                        repeat(
                            seq(
                                optional(
                                    seq(field("parameter", $.identifier), ":"),
                                ),
                                $.type,
                                ",",
                            ),
                        ),
                        optional(seq(field("parameter", $.identifier), ":")),
                        $.type,
                    ),
                ),
                ")",
            ),
        block: ($) => seq("{", repeat($._statement), "}"),
        _statement: ($) => choice($._definition, $.return_statement),
        return_statement: ($) => seq("return", $.expression, ";"),
        identifier: (_) => /[a-zA-Z_][a-zA-Z0-9_]*/,
        number: (_) => /[0-9]+((\.[0-9]*)|)/,
        fn_access: ($) => seq($.fn, $.identifier),
        expression: ($) =>
            choice(
                $.number,
                $.identifier,
                $.fn_access,
                $.binary_operator,
                $.unary_operator,
                // $.object_access,
                $.function_call,
                // $.object_literal,
                // $.anon_function,
                $.array_access,
                $.array_literal,
                $.string_literal,
                // $.import_expression,
                $.character_literal,
                $.boolean_literal,
            ),
        boolean_literal: (_) => choice("true", "false"),
        character_literal: ($) =>
            seq("'", choice(/[^']/, $.escape_sequence), "'"),
        escape_sequence: (_) => /\\./,
        // import_path: (_) => /[\.\/a-zA-Z0-9_]+/,
        // import_expression: ($) => seq("import", $.import_path),
        string_literal: ($) =>
            seq('"', repeat(choice(/[^"]/, $.escape_sequence)), '"'),
        op_eq: (_) => "=",
        comma: (_) => ",",
        // object_key: ($) =>
        //     seq(
        //         choice($.identifier, $.number),
        //         $.op_eq,
        //         $.expression,
        //         optional(","),
        //         repeat1($.EOS),
        //     ),
        // object_literal: ($) =>
        //     seq("{", repeat($.EOS), repeat($.object_key), "}"),
        array_literal: ($) =>
            seq(
                "[",
                // repeat($.EOS),
                optional(seq(repeat(seq($.expression, ",")), $.expression)),
                "]",
            ),
        argument_list: ($) =>
            seq(
                "(",
                optional(
                    choice(
                        $.expression,
                        seq(repeat(seq($.expression, ",")), $.expression),
                    ),
                ),
                ")",
            ),
        function_call: ($) =>
            seq(field("caller", choice($.assignable)), $.argument_list),
        object_access: ($) =>
            prec(1, seq($.identifier, repeat1(seq(".", $.identifier)))),
        array_access: ($) =>
            prec(1, seq($.expression, repeat1(seq("[", $.expression, "]")))),
        unary_operator: ($) =>
            choice(
                prec.left(3, seq("-", $.expression)),
                prec.left(3, seq("!", $.expression)),
            ),
        assignable: ($) =>
            choice($.identifier, $.object_access, $.array_access),
        binary_operator: ($) =>
            choice(
                prec.left(
                    5,
                    seq(
                        field("left", $.expression),
                        field("op", "*"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    5,
                    seq(
                        field("left", $.expression),
                        field("op", "/"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    6,
                    seq(
                        field("left", $.expression),
                        field("op", "+"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    6,
                    seq(
                        field("left", $.expression),
                        field("op", "-"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    9,
                    seq(
                        field("left", $.expression),
                        field("op", "<"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    9,
                    seq(
                        field("left", $.expression),
                        field("op", ">"),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    9,
                    seq(
                        field("left", $.expression),
                        field("op", ">="),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    9,
                    seq(
                        field("left", $.expression),
                        field("op", "=="),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    9,
                    seq(
                        field("left", $.expression),
                        field("op", "<="),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    16,
                    seq(
                        field("left", $.assignable),
                        field("op", "="),
                        field("right", $.expression),
                    ),
                ),
                prec.left(
                    16,
                    seq(
                        field("left", $.assignable),
                        field("op", "+="),
                        field("right", $.expression),
                    ),
                ),
            ),
    },
});
