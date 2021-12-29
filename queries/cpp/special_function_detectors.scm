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
                    (operator_name
                        "operator" "="
                    ) 
                    (parameter_list
                        (parameter_declaration
                            (abstract_reference_declarator "&") 
                        )
                    )
                )
            ) @assignment_operator_reference_declarator
        )
    )
) @class

;move assignment constructor detector 
(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        (field_declaration
            (reference_declarator 
                (function_declarator 
                    (operator_name
                        "operator" "="
                    )  
                    (parameter_list
                        (parameter_declaration
                            (abstract_reference_declarator "&&") 
                        )
                    )
                )
            ) @move_assignment_operator_reference_declarator
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
                        declarator: (abstract_reference_declarator "&")
                    )
                )
            )@copy_construct_function_declarator ;since we need the coordinates
        )
    )
) @class

;move construct detector
(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        (declaration
            (function_declarator 
                (parameter_list
                    (parameter_declaration
                        type: (type_identifier) @copy_construct_args
                        (#eq? @copy_construct_args @class_name)
                        declarator: (abstract_reference_declarator "&&")
                    )
                )
            )@move_construct_function_declarator ;since we need the coordinates
        )
    )
) @class
