(identifier) @identifier

(init_declarator
    (identifier) @init_declare_identifier
)

(function_declarator 
    (parameter_list 
        (parameter_declaration
            (identifier) @init_declare_identifier
        )
    )
)

;pointer or reference (upto 2 levels)
(function_declarator 
    (parameter_list 
        (parameter_declaration
            (_
                (identifier) @init_declare_identifier
            )
        )
    )
)

(function_declarator 
    (parameter_list 
        (parameter_declaration
            (_
                (_
                    (identifier) @init_declare_identifier
                )
            )
        )
    )
)


