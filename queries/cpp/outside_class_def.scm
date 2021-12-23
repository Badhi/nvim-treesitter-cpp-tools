(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        [
        (field_declaration
            (type_qualifier)* @return_type_qualifier
            type: (_)* @return_type
            declarator: [(function_declarator)* @fun_dec 
                         (reference_declarator)* @ref_fun_dec]
        )
        (declaration
           declarator: (function_declarator)* @fun_dec
        )
        ]
    )
) @class
