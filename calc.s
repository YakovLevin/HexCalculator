section	.rodata			; we define (global) read-only variables in .rodata section
    format_string: db "%s", 10, 0	    ; format string sor fprinf
    format_number: db "%d", 10, 0	    ; format string sor fprinf
    newline: db  10 , 0
    print_char: db "%X" , 0

    NOT_ENOUGH_ERR: db "Error: Insufficient Number of Arguments on Stack" , 10 , 0
    TOO_MUCH_ERR: db  "Error: Operand Stack Overflow", 10 , 0

    DEBUG_STR: db " -D : The input from the user is %s"  , 0
    DEBUG_NUM db " -D : The latest number pushed to the stack was %X" , 10 , 0

    calc: db "calc: ", 0            
    link_size: db 5
    max_input_length: db 80

section .bss
    OP_STACK: resd 1                    ; pointer to the OP_STACK
    STACK_SIZE: resd 1                  ; stack size
    COUNTER: resd 1                     ; counter for how many numbers we have in OP_STACK
    OP_COUNTER resd 1                   ; counter to count operations
    DEBUG resd 1                        ; flag for debug
    
    NEXT_LINK: resd 1                   ; pointer to the next link
    CHAR_COUNTER: resd 1                ; count length of numbers

    IN_BUFF: resb 80                    ; input buffer

section .text                           ; extern the given standart libary function
  align 16
  global main
  extern printf
  extern fprintf 
  extern fflush
  extern malloc 
  extern calloc 
  extern free 
  extern gets 
  extern getchar 
  extern fgets
  extern stdin 
  extern stderr

%macro get_link_ptr 0
    push 5        			            ; the size of each block im memory
    push 1                              ; the amount of blocks in memory
	call calloc             		    ; call malloc	
	add esp, 8                          ; remove argumant from the stack  
%endmacro

%macro fill_not_first_link 0
    get_link_ptr
    pop edx 
    do_debug_num edx
    mov [eax] , dl
    mov ebx , [NEXT_LINK]
    mov [eax + 1] , ebx
    mov [NEXT_LINK] , eax
%endmacro    

%macro check_for_single_value 1
    cmp dword [COUNTER] , 0             ; compare COUNTER with zero, to determain if stack is empty
    jne %1                              ; return to given label, and continue 
    push NOT_ENOUGH_ERR                 ; print ERORR
    call printf
    add esp,4                           ; remove argumant from the stack  
    jmp input_req                       ; return to get another input
%endmacro

%macro check_for_double_value 1
    cmp dword [COUNTER] , 2             ; compare COUNTER with two, to determain if stack has 2 numbers
    jge %1                              ; return to given label if equal or greater, and continue 
    push NOT_ENOUGH_ERR                 ; print ERORR
    call printf
    add esp,4               add esp,4                           ; remove argumant from the stack  
                ; remove argumant from the stack  
    jmp input_req                       ; return to get another input
%endmacro

%macro check_if_full 1
    mov ebx , [COUNTER]                 ; move to ebx the amount of numbers in OP_STACK
    cmp ebx, [STACK_SIZE]               ; check if amount is equal to STACK_SIZE
    jne %1                              ; return to given label, and continue  
    push TOO_MUCH_ERR                   ; print ERORR
    call printf
    add esp , 4                         ; remove argumant from the stack  
    jmp input_req                       ; return to get another input
%endmacro


%macro push_digits_of_top_to_stack 0
    mov dword [CHAR_COUNTER] , 0        ; reset the CHAR_COUNTER
    mov ecx , [COUNTER]                 ; move to ecx the amount of numbers in OP_STACK
    mov edx , [OP_STACK]                ; move to edx the address of OP_STACK
    mov eax , [edx + (4*ecx)]           ; move to eax the address of the first link, in the top of the OP_STACK
%%next_num:
    mov edx , 0                         ; reset edx
    mov dl , [eax]                      ; move the first byte of the link to dl, which contain a number between 0 to 15
    push edx                            ; push that number to the stack
    inc dword [CHAR_COUNTER]            ; increment CHAR_COUNTER, the amount of numbers we have pushed
    add dword eax , 1                   ; increment eax to get to the second part of the link, the pointer to the next link
    mov ebx , [eax]                     ; move ebx to point to the next link
    mov eax , ebx                       ; move next link to eax, for the loop
    cmp dword eax , 0                   ; check that next link != NULL
    jne %%next_num
%endmacro

%macro push_two_chain_pointers 0 
        mov eax , [OP_STACK]            ; get eax to point to the stack

        dec dword [COUNTER]             ; COUNTER-- , to point to the number on top of the stack
        mov ecx , [COUNTER]             ; move the counter to ecx
        mov ebx , [eax + (4*ecx)]       ; get ebx to point to the start of the chain of the number Y
        push ebx                        ; push the Y pointer to the stack

        dec dword [COUNTER]             ; COUNTER-- , to point to the number second from the top of the stack
        mov ecx , [COUNTER]             ; move the counter to ecx
        mov ebx , [eax + (4*ecx)]       ; get ebx to point to the start of the chain of the number X
        push ebx                        ; push the X pointer to the stack
 %endmacro
       

%macro end_addition_offset 1 
    mov edx , 0
    mov ebx , %1
    mov esi , [ebx + 1]
%%next_link_off:    
    mov dl , [esi]
    add dl , cl 
    mov ecx , 0
    cmp dl , 16
    jl %%no_overflow
    mov ecx , 1
    sub dl , 16
%%no_overflow:
    push edx
    inc dword [CHAR_COUNTER]
    cmp dword [esi + 1] , 0
    je %%handle_carry
    mov eax , [esi+1]
    mov esi , eax
    jmp %%next_link_off

%%handle_carry:
    cmp ecx , 1
    jne %%end_offset
    push 1
    inc dword [CHAR_COUNTER]
%%end_offset:
%endmacro

%macro end_or_offset 1
    mov edx , 0
    mov ebx , %1
    mov esi , [ebx + 1]
%%next_link_off:    
    mov dl , [esi]
    push edx
    inc dword [CHAR_COUNTER]
    cmp dword [esi + 1] , 0
    je %%end_offset_or
    mov eax , [esi+1]
    mov esi , eax
    jmp %%next_link_off

%%end_offset_or:
%endmacro

%macro convert_num_to_hex 1
	mov dword [CHAR_COUNTER], 0
	mov ebx, 16			; for %16 to hexa value
    mov eax , %1
%%int_to_hex:
	mov edx, 0
	div ebx				; %16
	push edx			; the value is back order
	inc dword [CHAR_COUNTER]				; in result.length by 1 (char)
	cmp eax, 0			; if eax=0 we convert the whole word
	jne %%int_to_hex
%endmacro


%macro add_new_chain_to_stack 0
        mov ecx , [COUNTER]
        mov edx , [OP_STACK]
        mov [edx + (4*ecx) ], eax       ; push NEXT to stack
        inc dword [COUNTER]
        mov dword [NEXT_LINK] , 0
        mov dword [CHAR_COUNTER] , 0
%endmacro    

%macro do_debug_str 1    
cmp dword[DEBUG], 1
jne %%no_d
        push %1                
        push DEBUG_STR          
        push dword [stderr]
        call fprintf
        add esp, 12
    %%no_d:
%endmacro

%macro do_debug_num 1    
cmp dword[DEBUG], 1
jne %%no_d1
        pushad
        push %1                
        push DEBUG_NUM          
        push dword [stderr]
        call fprintf
        add esp, 12
        popad
    %%no_d1:
%endmacro

%macro checker 1
    mov eax , %1                 ; move the string input to eax
    cmp eax , 0xA71                     ; check if 'q' and \n
    je end                              ; if yes, then go to the end

    cmp eax , 0xA2B                     ; check if '+' and \n
    je addition_op                      ; if yes, then go to addition_op

    cmp eax , 0xA70                     ; check if 'p' and \n
    je pop_and_print                    ; if yes, then go to pop_and_print

    cmp eax , 0xA64                     ; check if 'd' and \n
    je duplicate_op                     ; if yes, then go to duplicate_op

    cmp eax , 0xA26                     ; check if '&' and \n
    je and_op                           ; if yes, then go to and_op

    cmp eax , 0xA7C                     ; check if '|' and \n
    je or_op                            ; if yes, then go to or_op

    cmp eax , 0xA6E                     ; check if 'n' and \n
    je counter_op                       ; if yes, then go to counter_op

%endmacro

%macro free_chain 1
    mov dword [CHAR_COUNTER] , 0        ; reset CHAR_COUNTER
    mov esi , %1                        ; mov link adress to esi
%%push_and_proccead:
    inc dword [CHAR_COUNTER]            ; chain length ++
    push esi                            ; push link address
    inc esi                             ; move to the second part of the link 
    mov ebx , [esi]                     ; move next link address to ebx
    mov esi , ebx                       ; move next link address to esi
    cmp dword esi , 0                   ; check if there is a next link
    jne %%push_and_proccead


%%reached_end:
    dec dword [CHAR_COUNTER]            ; chain length --
    call free                           ; free link from top of stack
    add esp , 4                         ; remove argumant from the stack  
    cmp dword [CHAR_COUNTER] , 0        ; check if there is more link on stack
    jne %%reached_end

%endmacro

%macro free_two_latest 0
    pushad
    mov ecx , dword [COUNTER]
    mov eax , dword [OP_STACK]
    mov esi , [eax + (4*ecx)]
    free_chain esi
    mov ecx , dword [COUNTER]
    mov eax , dword [OP_STACK]
    inc ecx
    mov esi , [eax + (4*ecx)]
    free_chain esi
    popad
%endmacro

%macro clean_stack 0
%%check_stack:
    cmp dword [COUNTER] , 0
    je %%empty_stack
    dec dword [COUNTER]
    mov ecx , [COUNTER]
    mov edx , [OP_STACK]
    mov esi , [edx + (4*ecx)]
    free_chain esi
    jmp %%check_stack
%%empty_stack:
    push dword [OP_STACK]
    call free
    add esp, 4     
%endmacro

ascii_to_num:       
        mov eax, 0
        mov ebx, 0
        mov bl, [ecx]		            ; geting only first char (byte) from pointer so sreing

    next_ascii_char:
        cmp bl , '9'
        jg letter
        sub bl, '0'			            ; getting numeric value of char
        jmp continue_ascii_num
    letter:
        sub bl , 55    
    continue_ascii_num:        
        add eax, ebx 		            ; accunulating the resuly to eax
        inc ecx				            ; moving to the next char
        mov bl, [ecx]		            ; geting only first char (byte) from pointer so sreing
        cmp bl, 0			
        jne multiply_numbers
        ret		
    multiply_numbers:    
        mov edx, 16			; multyply by 10 the accumulating result
        mul edx				; for exampleL 479 = (((4*10)+7)*10)+9)
        jmp next_ascii_char
  


main:                        ; ///////////////////////////            MAIN             /////////////////////////////////     
	push ebp
	mov ebp, esp	
	pushad

    mov dword [COUNTER], 0
    mov dword [NEXT_LINK] , 0
    mov dword [CHAR_COUNTER] , 0
    mov dword [OP_COUNTER] , 0



define_stack:
        mov edx , [ebp + 8]
        cmp edx , 3
        je specified_size_stack_and_debug
        cmp edx , 2
        je two_args

    default_size_stack:
        mov dword [STACK_SIZE] , 5
        jmp initialize_stack

    two_args:
        mov edx , [ebp + 12]
        add edx , 4
        mov ecx , [edx]

        cmp word [ecx], '-d'
        jne specified_size_stack
        mov dword [DEBUG] , 1
        jmp default_size_stack


     specified_size_stack_and_debug:   
        mov dword [DEBUG] , 1
        mov edx , [ebp + 12]
        add edx , 4
        mov ecx , [edx]
        cmp word [ecx], '-d'
        jne specified_size_stack
        add edx , 4
        mov ecx , [edx] 

        call ascii_to_num 
        mov [STACK_SIZE], eax
        jmp initialize_stack


    specified_size_stack:   
        mov edx , [ebp + 12]
        add edx , 4
        mov ecx , [edx] 

        call ascii_to_num 
        mov [STACK_SIZE], eax
    
        
    initialize_stack:
        mov eax, [STACK_SIZE]           ; move STACK_SIZE to eax
        mov ebx , 4                     ; move 4 into ebx, the size of each pointer

        push ebx
        push eax                        ; provide STACK_SIZE * 4 as an argumant for calloc (the needed space for the stack)
        call calloc                     ; get a pointer to STACK_SIZE * 4 bytes in memory into eax
        mov [OP_STACK], eax             ; move the pointer to OP_STACK
        add esp, 8                      ; remove argumant from the stack  




input_req:                              ; input request :
    push calc                           ; print message " calc : "
    call printf             
    add esp, 4                          ; remove argumants from the stack            

    mov dword [IN_BUFF] , 0             ; reset IN_BUFF
    push dword [stdin]                  ; provide STDIN as an argumant for fgets
    push dword max_input_length         ; provide the max length as an argumant
    push dword IN_BUFF                  ; provide IN_BUFF as an argumant
    call fgets                      
    add esp, 12                         ; remove argumants from the stack    

    do_debug_str eax
    checker dword [IN_BUFF]  

    check_if_full add_number_to_stack

add_number_to_stack:
    mov dword [CHAR_COUNTER] , 0
    mov edx, 0
    mov dl, [IN_BUFF]
    mov ecx , 0

    chain_number:

        cmp dl, 10                     ; '\n'
        je end_conversion
        push ecx
    create_chain:
        cmp dl, '9'
        jle digit_conversion
        sub dl, 55
        jmp create_link 
    digit_conversion:
        sub dl, '0'
    create_link:
        cmp dword [CHAR_COUNTER] ,  0     ;so first link->next point to 0
        jg not_first_num

        cmp edx , 0
        je move_digit

        push edx
        get_link_ptr
        pop edx

        do_debug_num edx
        mov [eax] , dl                  ;first num
        mov dword [eax + 1] , 0
        mov [NEXT_LINK], eax
        inc dword [CHAR_COUNTER]
        jmp move_digit

    not_first_num:
        push edx
        fill_not_first_link
        inc dword [CHAR_COUNTER]

    move_digit:
        pop ecx
        inc ecx
        mov dl, [IN_BUFF + ecx]
        jmp chain_number
    end_conversion:  
        add_new_chain_to_stack

    jmp input_req


addition_op:
        inc dword [OP_COUNTER]
        check_for_double_value get_two_chains_add

    get_two_chains_add:
        mov dword [NEXT_LINK] , 0       ; reset NEXT_LINK
        mov dword [CHAR_COUNTER] , 0    ; reset CHAR_COUNTER
        push_two_chain_pointers
        mov ecx , 0                     ; reset carry

    adder:
        mov edx , 0                     ; reset edx
        mov ebx , 0                     ; reset ebx
        pop esi                         ; pop X pointer, or the next link (Xi)
        pop edi                         ; pop Y pointer, or the next link (Yi)

        inc dword [CHAR_COUNTER]        ; increase CHAR_COUNTER for another link in the result
        mov dl , [esi]                  ; get Xi to dl
        mov bl , [edi]                  ; get Yi to bl
        add dl , bl                     ; add the two values (Xi + Yi = Zi)
        add dl , cl                     ; add carry (Zi + C)
        mov ecx , 0                     ; reset carry register
        cmp dl , 16                     ; check if Zi overflows
        jl no_carry                     ; if no continue
        sub dl , 16                     ; equivalent to dl % 16
        mov ecx, 1                      ; turn on carry flag

    no_carry:
    
        push edx                        ; store Zi in the stack

        cmp dword [esi+1] , 0           ; check if X is over
        je check_other_number

        cmp dword [edi+1] , 0           ; check if Y is over
        jne move_digit_add              ; both are NOT over, continue to the next i

        end_addition_offset esi         ; push the rest of X to the stack
        jmp create_chain_from_stack_add ; start creating the Z chain


    check_other_number:
        cmp dword [edi+1] , 0           ; check if Y is over
        je create_chain_from_stack_add  ; if yes, both are over and go start creating the Z chain

        end_addition_offset edi         ; push the rest of Y to the stack
        jmp create_chain_from_stack_add ; start creating the Z chain


    move_digit_add:
        mov eax , [edi + 1]             ; get address of next link of Yi+1
        push eax                        ; push that address
        mov ebx , [esi + 1]             ; get address of next link of Xi+1
        push ebx                        ; push that address

        jmp adder

    create_chain_from_stack_add: 
        cmp ecx , 0                     ; check if theres carry in the end
        je first_link_add               ; if no continue
        push 1                          ; if yes, push 1 to the start of Z
        inc dword [CHAR_COUNTER]        ; and incremnt the size of the chain
    first_link_add:    
        get_link_ptr
        pop edx
        do_debug_num edx
        mov [eax] , dl
        mov dword [eax + 1] , 0
        mov [NEXT_LINK], eax             
        dec dword [CHAR_COUNTER]        ; 

    crate_link_add:    
        cmp dword [CHAR_COUNTER] , 0
        je end_add
        fill_not_first_link
        dec dword [CHAR_COUNTER]
        jmp crate_link_add


    end_add:
        free_two_latest
        add_new_chain_to_stack

        jmp input_req


pop_and_print:
        inc dword [OP_COUNTER]
        check_for_single_value continue_print

    continue_print:    
        dec dword [COUNTER]
        push_digits_of_top_to_stack 

    print_number:

        push print_char
        call printf
        add esp, 8
        dec dword [CHAR_COUNTER]
        cmp dword [CHAR_COUNTER] , 0
        jne print_number

        push newline
        call printf
        add esp, 4

                
        mov ecx , dword [COUNTER]
        mov eax, [OP_STACK]
        mov esi , [eax + (4*ecx)]
        free_chain esi
        

    jmp input_req

duplicate_op:
        inc dword [OP_COUNTER]
        check_for_single_value next_check_dup
    next_check_dup:    
        check_if_full continue_dup
    continue_dup:
        mov dword [NEXT_LINK] , 0
        dec dword [COUNTER] 
        push_digits_of_top_to_stack 

    build_chain_dup:
        inc ecx
        push ecx
        get_link_ptr
        pop ecx
        pop edx  
        do_debug_num edx
        cmp ecx, 1
        jg not_first_dup

        mov [eax] , dl
        mov dword [eax + 1], 0
        mov [NEXT_LINK], eax
        jmp next_digit_dup

    not_first_dup:
        mov [eax] , dl
        mov ebx , [NEXT_LINK]
        mov dword [eax + 1] , ebx
        mov [NEXT_LINK], eax

    next_digit_dup:
        dec dword [CHAR_COUNTER]
        cmp dword [CHAR_COUNTER], 0
        jne build_chain_dup
    end_dup:
        inc dword [COUNTER]
        add_new_chain_to_stack
        jmp input_req
    

and_op:
        inc dword [OP_COUNTER]
        check_for_double_value get_two_chains_and
    get_two_chains_and:
        mov dword [NEXT_LINK] , 0       ; reset NEXT_LINK
        mov dword [CHAR_COUNTER] , 0    ; reset CHAR_COUNTER
        push_two_chain_pointers   

    and_single_link:
        mov edx , 0                     ; reset edx
        mov ebx , 0                     ; reset ebx
        pop esi                         ; pop X pointer, or the next link (Xi)
        pop edi                         ; pop Y pointer, or the next link (Yi)

        inc dword [CHAR_COUNTER]        ; increase CHAR_COUNTER for another link in the result
        mov dl , [esi]                  ; get Xi to dl
        mov bl , [edi]                  ; get Yi to bl
        and dl , bl                     ; and operation between Xi and Yi
        push edx                        ; save the result

        cmp dword [esi+1] , 0           ; check if X is over
        je first_link_and

        cmp dword [edi+1] , 0           ; check if Y is over
        je first_link_and               ; both are NOT over, continue to the next i

    move_digit_and:
        mov eax , [edi + 1]             ; get address of next link of Yi+1
        push eax                        ; push that address
        mov ebx , [esi + 1]             ; get address of next link of Xi+1
        push ebx                        ; push that address

        jmp and_single_link   

    first_link_and:
        cmp dword [CHAR_COUNTER] , 0
        je continue_first_link
        dec dword [CHAR_COUNTER]
        pop edx        
        cmp edx , 0
        je first_link_and

    continue_first_link:
        push edx
        get_link_ptr
        pop edx
        do_debug_num edx
        mov [eax] , dl
        mov dword [eax + 1] , 0
        mov [NEXT_LINK], eax             

    create_link_and:    
        cmp dword [CHAR_COUNTER] , 0
        je end_and
        fill_not_first_link
        dec dword [CHAR_COUNTER]
        jmp create_link_and

    end_and:
        free_two_latest
        add_new_chain_to_stack

        jmp input_req



or_op:
        inc dword [OP_COUNTER]
        check_for_double_value get_two_chains_or

    get_two_chains_or:
        mov dword [NEXT_LINK] , 0       ; reset NEXT_LINK
        mov dword [CHAR_COUNTER] , 0    ; reset CHAR_COUNTER
        push_two_chain_pointers

    or_single_link:
        mov edx , 0                     ; reset edx
        mov ebx , 0                     ; reset ebx
        pop esi                         ; pop X pointer, or the next link (Xi)
        pop edi                         ; pop Y pointer, or the next link (Yi)

        inc dword [CHAR_COUNTER]        ; increase CHAR_COUNTER for another link in the result
        mov dl , [esi]                  ; get Xi to dl
        mov bl , [edi]                  ; get Yi to bl
        or dl , bl                      ; or operation between Xi and Yi
        push edx                        ; save the result

        cmp dword [esi+1] , 0           ; check if X is over
        je check_other_number_or

        cmp dword [edi+1] , 0           ; check if Y is over
        jne move_digit_or               ; both are NOT over, continue to the next i

        end_or_offset esi               ; push the rest of X to the stack
        jmp first_link_or               ; start creating the Z chain


    check_other_number_or:
        cmp dword [edi+1] , 0           ; check if Y is over
        je first_link_or                ; if yes, both are over and go start creating the Z chain

        end_or_offset edi               ; push the rest of Y to the stack
        jmp first_link_or               ; start creating the Z chain

    
    move_digit_or:
        mov eax , [edi + 1]             ; get address of next link of Yi+1
        push eax                        ; push that address
        mov ebx , [esi + 1]             ; get address of next link of Xi+1
        push ebx                        ; push that address

        jmp or_single_link    


    first_link_or:    
        get_link_ptr
        pop edx
        do_debug_num edx
        mov [eax] , dl
        mov dword [eax + 1] , 0
        mov [NEXT_LINK], eax             
        dec dword [CHAR_COUNTER]        ; 

    create_link_or:    
        cmp dword [CHAR_COUNTER] , 0
        je end_or
        fill_not_first_link
        dec dword [CHAR_COUNTER]
        jmp create_link_or

    end_or:
        free_two_latest
        add_new_chain_to_stack

        jmp input_req



counter_op:
        inc dword [OP_COUNTER]
        check_for_single_value continue_count

    continue_count:
        dec dword [COUNTER]
        push_digits_of_top_to_stack 

        mov ecx , [CHAR_COUNTER]

    clean_stack_count:
        pop edx
        dec dword [CHAR_COUNTER]
        cmp dword [CHAR_COUNTER] , 0
        jne clean_stack_count

        convert_num_to_hex ecx

        get_link_ptr
        dec dword [CHAR_COUNTER]
        pop edx
        do_debug_num edx
        mov [eax] , dl
        mov dword [eax + 1] , 0
        mov [NEXT_LINK] , eax

    not_first_count:
        cmp dword [CHAR_COUNTER] , 0
        je end_counter
        dec dword [CHAR_COUNTER]
        fill_not_first_link
        jmp not_first_count

    end_counter:
        pushad
        mov ecx , [COUNTER]
        mov eax , [OP_STACK]
        mov esi , [eax + (4*ecx)]
        free_chain esi
        popad
        add_new_chain_to_stack
        jmp input_req


end:
        mov ecx , [OP_COUNTER]
        convert_num_to_hex ecx
    print_number_end:

        push print_char
        call printf
        add esp, 8
        dec dword [CHAR_COUNTER]
        cmp dword [CHAR_COUNTER] , 0
        jne print_number_end

        push newline
        call printf
        add esp, 4

    clean_stack


	popad			
	mov esp, ebp	
	pop ebp
    mov eax, 1                      ; call exit
    int 0x80    
