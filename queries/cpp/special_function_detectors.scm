;; destructor filter detector
(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        (declaration 
            (function_declarator 
                (destructor_name) @destructor
            )
        )
    )
) @class

;assignment constructor detector 
(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        (field_declaration
            (reference_declarator 
                (function_declarator 
                    (operator_name) @assignment_operator
                    (#match? @assignment_operator "operator=")
                )
            ) @assignment_operator_reference_declarator
        )
    )
) @class

;copy construct detector
(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        (declaration
            (function_declarator 
                (parameter_list
                    (parameter_declaration
                        type: (type_identifier) @copy_construct_args
                        (#eq? @copy_construct_args @class_name)
                    )
                )
            )@copy_construct_function_declarator ;since we need the coordinates
        )
    )
) @class
