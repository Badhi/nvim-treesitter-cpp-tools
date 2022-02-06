(class_specifier
    name: (type_identifier)
    body: (field_declaration_list
       [(template_declaration
                (declaration
                    [(function_declarator) (reference_declarator 
                                                (function_declarator))])@member_function
        )
        (field_declaration
            [(function_declarator) (reference_declarator
                                        (function_declarator))]
        ) 
        (declaration
            [(function_declarator) (reference_declarator
                                        (function_declarator))]
        )
        ]@member_function
    )
)

