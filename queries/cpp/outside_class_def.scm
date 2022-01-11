(template_declaration 
    (template_parameter_list 
        (
            (type_parameter_declaration 
                (type_identifier)* @template_parameters
            )
        )
    )@template_param_list
)

(class_specifier
    name: (type_identifier) @class_name
    body: (field_declaration_list
        [
        (field_declaration
            (type_qualifier)* @return_type_qualifier
            type: (_)* @return_type
            declarator: [(function_declarator)* @fun_dec 
                         (reference_declarator
                            (function_declarator)@ref_fun_dec)* ]
        )
        (declaration
           declarator: (function_declarator)* @fun_dec
        )
        ]
    )
) @class

;(class_specifier
;    name: (type_identifier) @class_name
;    body: (field_declaration_list
;        [
;        (field_declaration
;            (type_qualifier)* @return_type_qualifier
;            type: (_)* @return_type
;            declarator: [(function_declarator)* @fun_dec 
;                         (reference_declarator
;                            (function_declarator))* @ref_fun_dec]
;        )
;        (template_declaration
;            (template_parameter_list 
;                (type_parameter_declaration 
;                    (type_identifier)* @member_template_params
;                )
;            ) @member_templates_list
;            (declaration 
;                (type_qualifier)* @return_type_qualifier
;                type: (_)* @return_type
;                declarator: [(function_declarator)* @fun_dec 
;                             (reference_declarator
;                                (function_declarator))* @ref_fun_dec]
;            )
;        ) 
;        (declaration
;           declarator: (function_declarator)* @fun_dec
;        )
;        ]
;    )
;) @class
