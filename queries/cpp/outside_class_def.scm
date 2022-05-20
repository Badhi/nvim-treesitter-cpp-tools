(_
    body: (_
       [
           (template_declaration
                (declaration
                    [
                        (function_declarator) 
                        (reference_declarator
                            (function_declarator))
                        (pointer_declarator
                            (function_declarator)) 
                    ]
                )@member_function
            )
            (field_declaration
                [
                    (function_declarator) 
                    (reference_declarator
                        (function_declarator))
                    (pointer_declarator
                        (function_declarator))
                ]
            ) 
            (declaration
                [
                    (function_declarator) 
                    (reference_declarator
                        (function_declarator))
                    (pointer_declarator
                        (function_declarator))
                ]
            )
        ]@member_function
    )
)
; (_
;     body: (compound_statement
;        [
;            (template_declaration
;                 (declaration
;                     [
;                         (function_declarator) 
;                         (reference_declarator
;                             (function_declarator))
;                         (pointer_declarator
;                             (function_declarator)) 
;                     ]
;                 )@member_function
;             )
;             (field_declaration
;                 [
;                     (function_declarator) 
;                     (reference_declarator
;                         (function_declarator))
;                     (pointer_declarator
;                         (function_declarator))
;                 ]
;             ) 
;             (declaration
;                 [
;                     (function_declarator) 
;                     (reference_declarator
;                         (function_declarator))
;                     (pointer_declarator
;                         (function_declarator))
;                 ]
;             )
;         ]@member_function
;     )
; )
