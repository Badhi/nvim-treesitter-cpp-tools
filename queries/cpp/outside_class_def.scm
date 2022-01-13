(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        [
            (field_declaration
                [(function_declarator) (reference_declarator)]
            ) 
            (declaration
                (function_declarator)
            )
        ]@member_function
    )
) @class
