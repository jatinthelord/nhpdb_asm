
  
; ================================================================
;  FUNCTION: print_table_header_customers
;  Columns: Name | Country | City | Age
; ================================================================
print_hdr_all_customers:
    PRINT sep_line, sep_len
    PRINT hdr_name,    hdr_name_l
    PRINT pipe_sep,    pipe_sep_l
    PRINT hdr_country, hdr_country_l
    PRINT pipe_sep,    pipe_sep_l
    PRINT hdr_city,    hdr_city_l
    PRINT pipe_sep,    pipe_sep_l
    PRINT hdr_age,     hdr_age_l
    PRINT newline, 1
    PRINT sep_line, sep_len
    ret

print_hdr_country_city:
    PRINT sep_line, sep_len
    PRINT hdr_country, hdr_country_l
    PRINT pipe_sep,    pipe_sep_l
    PRINT hdr_city,    hdr_city_l
    PRINT newline, 1
    PRINT sep_line, sep_len
    ret

print_hdr_name_age:
    PRINT sep_line, sep_len

; ================================================================
;  PARSER
;  Reads input_buf, parses NHPLang query syntax
;  Sets r14=table, r15=cols, rbx=sort, then calls execute_query
; ================================================================
parse_and_run:
    push r12
    push r13
    push r14
    push r15

    xor r14, r14            ; table = none
    xor r15, r15            ; cols  = all
    xor rbx, rbx            ; sort  = none

    lea rsi, [input_buf]
    call skip_spaces

    ; ── check for 'help' ──
    lea rdi, [kw_help]
    call starts_with
    test rax, rax
    jz  .not_help
    PRINT msg_help, msg_help_l
    jmp .parse_done
.not_help:

    ; ── check for line2 stored (column/sort spec after Select...;) ──
    ; if last_table != 0, this line is a column/sort spec
    mov rax, [last_table]
    test rax, rax
    jnz .is_colspec

    ; ── expect 'Select' ──
    lea rdi, [kw_select]
    call starts_with
    test rax, rax
    jnz .err_select

    ; skip 'Select'
    add rsi, 6
    call skip_spaces

    ; skip '*'
    mov al, [rsi]
    cmp al, '*'
    je  .has_star
    ; could be missing
    jmp .has_star           ; be lenient
.has_star:
    inc rsi
    call skip_spaces

    ; expect 'From'
    lea rdi, [kw_from]
    call starts_with
    test rax, rax
    jnz .err_from

    add rsi, 4
    call skip_spaces

    ; which table?
    lea rdi, [kw_customers]
    call starts_with
    test rax, rax
    jz  .is_customers

    lea rdi, [kw_seller]
    call starts_with
    test rax, rax
    jz  .is_seller

    PRINT err_unknown_table, err_unknown_table_l
    jmp .parse_done

.is_customers:
    mov r14, 1
    jmp .check_semi
.is_seller:
    mov r14, 2

.check_semi:
    ; find semicolon in remaining input
    ; if found, col spec might follow on same line or next prompt
    ; for simplicity: after ';' look for column spec on SAME line
    mov r12, rsi
.find_semi:
    mov al, [r12]
    test al, al
    jz  .no_semi_yet
    cmp al, ';'
    je  .found_semi
    inc r12
    jmp .find_semi
.no_semi_yet:
    ; store table, wait for next line
    mov [last_table], r14
    ; print prompt for col spec
    PRINT prompt, prompt_len
    ; read col spec line
    lea rsi, [input2_buf]
    mov rdx, 512
    call read_line
    lea rsi, [input2_buf]
    jmp .parse_colspec

.found_semi:
    inc r12                 ; skip ';'
    call skip_spaces
    ; check if col spec on same line
    mov al, [r12]
    test al, al
    jz  .no_colspec_inline  ; nothing after semicolon
    mov rsi, r12
    jmp .parse_colspec

.no_colspec_inline:
    ; prompt for col spec line
    PRINT prompt, prompt_len
    lea rsi, [input2_buf]
    mov rdx, 512
    call read_line
    lea rsi, [input2_buf]
    jmp .parse_colspec

.is_colspec:
    ; last_table already set, this line IS the col spec
    mov r14, [last_table]
    mov qword [last_table], 0
    ; rsi already points to input_buf (the col line)

.parse_colspec:
    call skip_spaces

    ; check for Country
    lea rdi, [kw_country]
    call starts_with
    test rax, rax
    jnz .not_country
    mov r15, 1              ; country+city mode
    ; check for + City
    jmp .colspec_seller_check
.not_country:

    ; check for Name
    lea rdi, [kw_name]
    call starts_with
    test rax, rax
    jnz .not_name
    mov r15, 2              ; name+age mode
    jmp .colspec_seller_check
.not_name:

    ; check for Food
    lea rdi, [kw_food]
    call starts_with
    test rax, rax
    jnz .not_food
    mov r15, 3              ; food+price mode
    ; look for Low_high or High_low on this same line
    push rsi
.scan_sort:
    mov al, [rsi]
    test al, al
    jz  .no_sort
    ; check Low_high
    lea rdi, [kw_low_high]
    call starts_with
    test rax, rax
    jnz .try_high_low
    mov rbx, 1              ; low_high
    jmp .no_sort
.try_high_low:
    lea rdi, [kw_high_low]
    call starts_with
    test rax, rax
    jnz .inc_scan
    mov rbx, 2              ; high_low
    jmp .no_sort
.inc_scan:
    inc rsi
    jmp .scan_sort
.no_sort:
    pop rsi
    jmp .colspec_seller_check
.not_fo


