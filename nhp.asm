; ================================================================
;  NHPLang Database Engine  v1.0  —  Pure x86-64 Assembly
;  Tera apna SQL jaisa database engine
;
;  NHPLang Query Syntax:
;    Select * From Customers;          -- saare columns
;    Country + City                     -- specific columns
;    Select * From Seller;
;    Food("Price/Mrp")                  -- price type column
;    Food("Price/Mrp") Low_high         -- sort low to high
;    Food("Price/Mrp") High_low         -- sort high to low
;
;  Compile (Termux/Linux):
;    nasm -f elf64 nhpdb_asm.asm -o nhpdb.o
;    ld nhpdb.o -o nhpdb
;    ./nhpdb
; ================================================================

global _start

; ================================================================
;  CONSTANTS
; ================================================================
%define SYS_READ    0
%define SYS_WRITE   1
%define SYS_OPEN    2
%define SYS_CLOSE   3
%define SYS_LSEEK   8
%define SYS_MMAP    9
%define SYS_EXIT    60
%define STDOUT      1
%define STDIN       0

%define MAX_ROWS    1000
%define MAX_COLS    16
%define COL_WIDTH   32      ; max chars per column value
%define NAME_LEN    32
%define PRICE_LEN   16

; ================================================================
;  DATA SECTION
; ================================================================
section .data

; ── UI strings ──
banner      db '================================================',10
            db '  NHPLang Database Engine  v1.0',10
            db '  Tera apna SQL — Assembly se bana',10
            db '================================================',10
banner_len  equ $ - banner

prompt      db 'nhpdb> '
prompt_len  equ $ - prompt

newline     db 10
sep_line    db '------------------------------------------------',10
sep_len     equ $ - sep_line
dbl_line    db '================================================',10
dbl_len     equ $ - dbl_line

msg_ok      db '[OK] ',0
msg_err     db '[ERROR] ',0
msg_warn    db '[WARN] ',0

; ── Error messages ──
err_unknown_table   db '[ERROR] Table not found. Use: Customers or Seller',10
err_unknown_table_l equ $ - err_unknown_table

err_syntax          db '[ERROR] Bad syntax. Example: Select * From Customers;',10
err_syntax_l        equ $ - err_syntax

err_no_select       db '[ERROR] Missing Select keyword.',10
err_no_select_l     equ $ - err_no_select

err_no_from         db '[ERROR] Missing From keyword.',10
err_no_from_l       equ $ - err_no_from

err_no_semicolon    db '[ERROR] Missing semicolon ; at end of table name.',10
err_no_semicolon_l  equ $ - err_no_semicolon

err_bad_col         db '[ERROR] Unknown column. For Customers: Country, City, Name, Age',10
                    db '        For Seller: Food, Price, Mrp, Stock',10
err_bad_col_l       equ $ - err_bad_col

err_bad_sort        db '[ERROR] Bad sort. Use: Low_high or High_low',10
err_bad_sort_l      equ $ - err_bad_sort

msg_rows_found      db 'Rows found: '
msg_rows_found_l    equ $ - msg_rows_found

msg_help            db 'Commands:',10
                    db '  Select * From Customers;           -- saare customers',10
                    db '  Country + City                     -- Country aur City columns',10
                    db '  Name + Age                         -- Name aur Age columns',10
                    db '  Select * From Seller;              -- saare sellers',10
                    db '  Food("Price/Mrp")                  -- food prices',10
                    db '  Food("Price/Mrp") Low_high         -- price low se high',10
                    db '  Food("Price/Mrp") High_low         -- price high se low',10
                    db '  insert customer <Name> <Country> <City> <Age>',10
                    db '  insert seller <Food> <Price> <Stock>',10
                    db '  help                               -- ye help',10
                    db '  exit                               -- band karo',10
msg_help_l          equ $ - msg_help

; ── Column headers ──
hdr_name        db 'Name            '
hdr_name_l      equ $ - hdr_name
hdr_country     db 'Country         '
hdr_country_l   equ $ - hdr_country
hdr_city        db 'City            '
hdr_city_l      equ $ - hdr_city
hdr_age         db 'Age   '
hdr_age_l       equ $ - hdr_age
hdr_food        db 'Food            '
hdr_food_l      equ $ - hdr_food
hdr_price       db 'Price(MRP)      '
hdr_price_l     equ $ - hdr_price
hdr_stock       db 'Stock '
hdr_stock_l     equ $ - hdr_stock
pipe_sep        db ' | '
pipe_sep_l      equ $ - pipe_sep

; ── Pre-loaded Customers table ──
; Format: Name[16] Country[16] City[16] Age[4]

c_name0     db 'Rahul           '; 16 chars
c_cntry0    db 'India           '
c_city0     db 'Mumbai          '
c_age0      db '25',0,0           ; 4 bytes

c_name1     db 'Alice           '
c_cntry1    db 'USA             '
c_city1     db 'New York        '
c_age1      db '30',0,0

c_name2     db 'Wang Li         '
c_cntry2    db 'China           '
c_city2     db 'Beijing         '
c_age2      db '28',0,0

c_name3     db 'Carlos          '
c_cntry3    db 'Brazil          '
c_city3     db 'Sao Paulo       '
c_age3      db '35',0,0

c_name4     db 'Priya           '
c_cntry4    db 'India           '
c_city4     db 'Delhi           '
c_age4      db '22',0,0

c_name5     db 'James           '
c_cntry5    db 'UK              '
c_city5     db 'London          '
c_age5      db '40',0,0

c_name6     db 'Fatima          '
c_cntry6    db 'UAE             '
c_city6     db 'Dubai           '
c_age6      db '27',0,0

c_name7     db 'Yuki            '
c_cntry7    db 'Japan           '
c_city7     db 'Tokyo           '
c_age7      db '33',0,0

; Number of customers
num_customers   dq 8

; Customer table: array of pointers [name, country, city, age_str]
cust_table:
    dq c_name0, c_cntry0, c_city0, c_age0
    dq c_name1, c_cntry1, c_city1, c_age1
    dq c_name2, c_cntry2, c_city2, c_age2
    dq c_name3, c_cntry3, c_city3, c_age3
    dq c_name4, c_cntry4, c_city4, c_age4
    dq c_name5, c_cntry5, c_city5, c_age5
    dq c_name6, c_cntry6, c_city6, c_age6
    dq c_name7, c_cntry7, c_city7, c_age7

; ── Pre-loaded Seller table ──
; Format: Food[16] Price[8] Stock[8]
s_food0     db 'Pizza           '
s_price0    db '250',0,0,0,0,0       ; price in rupees
s_stock0    db '50',0,0,0,0,0,0

s_food1     db 'Burger          '
s_price1    db '120',0,0,0,0,0
s_stock1    db '80',0,0,0,0,0,0

s_food2     db 'Biryani         '
s_price2    db '180',0,0,0,0,0
s_stock2    db '30',0,0,0,0,0,0

s_food3     db 'Pasta           '
s_price3    db '200',0,0,0,0,0
s_stock3    db '45',0,0,0,0,0,0

s_food4     db 'Dosa            '
s_price4    db '60',0,0,0,0,0
s_stock4    db '100',0,0,0,0,0,0

s_food5     db 'Sushi           '
s_price5    db '350',0,0,0,0,0
s_stock5    db '20',0,0,0,0,0,0

s_food6     db 'Tacos           '
s_price6    db '150',0,0,0,0,0
s_stock6    db '60',0,0,0,0,0,0

s_food7     db 'Noodles         '
s_price7    db '90',0,0,0,0,0
s_stock7    db '75',0,0,0,0,0,0

num_sellers dq 8

; Seller table: [food, price_str, stock_str]
sell_table:
    dq s_food0, s_price0, s_stock0
    dq s_food1, s_price1, s_stock1
    dq s_food2, s_price2, s_stock2
    dq s_food3, s_price3, s_stock3
    dq s_food4, s_price4, s_stock4
    dq s_food5, s_price5, s_stock5
    dq s_food6, s_price6, s_stock6
    dq s_food7, s_price7, s_stock7

; ── Keywords for parser ──
kw_select   db 'Select',0
kw_from     db 'From',0
kw_star     db '*',0
kw_customers db 'Customers',0
kw_seller   db 'Seller',0
kw_country  db 'Country',0
kw_city     db 'City',0
kw_name     db 'Name',0
kw_age      db 'Age',0
kw_food     db 'Food',0
kw_price    db 'Price',0
kw_mrp      db 'Mrp',0
kw_stock    db 'Stock',0
kw_low_high db 'Low_high',0
kw_high_low db 'High_low',0
kw_help     db 'help',0
kw_exit     db 'exit',0
kw_quit     db 'quit',0

; ── sort buffer (for prices) ──
; stores [price_int, original_index] pairs
sort_buf times 64 dq 0    ; 8 sellers max * 2 qwords each

; ── number to string buffer ──
num_str_buf db '          ',10
hex_chars   db '0123456789ABCDEF'

; ── rupee symbol ──
rupee_sym   db 'Rs.',0

; ── spacing ──
spaces      db '                '   ; 16 spaces

; ── result count buffer ──
count_buf   db '0000',10

; ── query line 2 buffer (for column/sort spec) ──
line2_buf   times 256 db 0

; ── table context: 0=none, 1=customers, 2=seller ──
last_table  dq 0

section .bss
    input_buf   resb 512
    input2_buf  resb 512
    tmp_buf     resb 128
    row_count   resq 1

section .text

; ================================================================
;  MACRO: print a string by address + length
; ================================================================
%macro PRINT 2
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro

; ================================================================
;  FUNCTION: strlen
;  Input:  rdi = null-terminated string
;  Output: rax = length
; ================================================================
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je  .done
    inc rax
    jmp .loop
.done:
    ret

; ================================================================
;  FUNCTION: strcmp
;  Input:  rsi = str1, rdi = str2
;  Output: rax = 0 if equal
; ================================================================
strcmp_fn:
    xor rax, rax
.loop:
    mov al,  [rsi]
    mov cl,  [rdi]
    cmp al, cl
    jne .not_eq
    test al, al
    jz  .equal
    inc rsi
    inc rdi
    jmp .loop
.not_eq:
    mov rax, 1
    ret
.equal:
    xor rax, rax
    ret

; ================================================================
;  FUNCTION: starts_with
;  Input:  rsi = string, rdi = prefix
;  Output: rax = 1 if starts with, else 0
; ================================================================
starts_with:
    push r8
    mov r8, rsi
.loop:
    mov al, [rdi]
    test al, al
    jz  .yes            ; prefix exhausted = match
    mov cl, [rsi]
    cmp al, cl
    jne .no
    inc rsi
    inc rdi
    jmp .loop
.yes:
    mov rax, 1
    pop r8
    ret
.no:
    xor rax, rax
    pop r8
    ret

; ================================================================
;  FUNCTION: str_to_int
;  Input:  rsi = digit string
;  Output: rax = integer value
; ================================================================
str_to_int:
    xor rax, rax
    xor rcx, rcx
.loop:
    movzx rcx, byte [rsi]
    test cl, cl
    jz .done
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    imul rax, rax, 10
    sub cl, '0'
    add rax, rcx
    inc rsi
    jmp .loop
.done:
    ret

; ================================================================
;  FUNCTION: int_to_str
;  Input:  rax = integer
;  Output: num_str_buf filled, r9 = length
; ================================================================
int_to_str:
    push rbx
    push rcx
    push rdx
    lea rdi, [num_str_buf]
    test rax, rax
    jnz .nonzero
    mov byte [rdi], '0'
    mov r9, 1
    mov byte [rdi+1], 0
    jmp .done
.nonzero:
    lea rbx, [num_str_buf + 19]
    mov byte [rbx], 0
    mov r9, 0
    mov rcx, 10
.loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rbx
    mov [rbx], dl
    inc r9
    test rax, rax
    jnz .loop
    ; copy to front
    push rsi
    mov rsi, rbx
    xor rcx, rcx
.copy:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .copy_done
    inc rcx
    jmp .copy
.copy_done:
    pop rsi
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ================================================================
;  FUNCTION: print_padded
;  Input:  rsi = string, rdx = pad_to_width
;  Prints string then spaces to fill width
; ================================================================
print_padded:
    push r12
    push r13
    push r14
    mov r12, rsi        ; save string
    mov r13, rdx        ; save width

    ; print the string
    mov rdi, rsi
    call strlen
    mov r14, rax        ; string length

    PRINT r12, r14

    ; print padding spaces
    mov rcx, r13
    sub rcx, r14
    jle .done
.pad_loop:
    PRINT spaces, 1
    dec rcx
    jnz .pad_loop
.done:
    pop r14
    pop r13
    pop r12
    ret

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
    PRINT hdr_name, hdr_name_l
    PRINT pipe_sep, pipe_sep_l
    PRINT hdr_age,  hdr_age_l
    PRINT newline, 1
    PRINT sep_line, sep_len
    ret

print_hdr_seller:
    PRINT sep_line, sep_len
    PRINT hdr_food,  hdr_food_l
    PRINT pipe_sep,  pipe_sep_l
    PRINT hdr_price, hdr_price_l
    PRINT pipe_sep,  pipe_sep_l
    PRINT hdr_stock, hdr_stock_l
    PRINT newline, 1
    PRINT sep_line, sep_len
    ret

; ================================================================
;  FUNCTION: print_customer_row
;  Input:  r12 = row index
;  Reads from cust_table
; ================================================================
print_customer_row_all:
    push r12
    push r13
    ; base = cust_table + r12 * 32 (4 pointers * 8 bytes)
    mov rax, r12
    imul rax, 32
    lea r13, [cust_table + rax]

    ; Name
    mov rsi, [r13]          ; name pointer
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l

    ; Country
    mov rsi, [r13 + 8]
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l

    ; City
    mov rsi, [r13 + 16]
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l

    ; Age
    mov rsi, [r13 + 24]
    mov rdi, rsi
    call strlen
    PRINT [r13+24], rax

    PRINT newline, 1
    pop r13
    pop r12
    ret

print_customer_row_cc:     ; Country + City only
    push r12
    push r13
    mov rax, r12
    imul rax, 32
    lea r13, [cust_table + rax]
    mov rsi, [r13 + 8]     ; Country
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l
    mov rsi, [r13 + 16]    ; City
    mov rdx, 16
    call print_padded
    PRINT newline, 1
    pop r13
    pop r12
    ret

print_customer_row_na:     ; Name + Age only
    push r12
    push r13
    mov rax, r12
    imul rax, 32
    lea r13, [cust_table + rax]
    mov rsi, [r13]          ; Name
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l
    mov rsi, [r13 + 24]     ; Age
    mov rdi, rsi
    call strlen
    PRINT [r13+24], rax
    PRINT newline, 1
    pop r13
    pop r12
    ret

; ================================================================
;  FUNCTION: print_seller_row
;  Input:  r12 = row index
; ================================================================
print_seller_row:
    push r12
    push r13
    mov rax, r12
    imul rax, 24            ; 3 pointers * 8
    lea r13, [sell_table + rax]

    mov rsi, [r13]          ; Food
    mov rdx, 16
    call print_padded
    PRINT pipe_sep, pipe_sep_l

    ; Price with Rs.
    PRINT rupee_sym, 3
    mov rsi, [r13 + 8]      ; Price
    mov rdi, rsi
    call strlen
    PRINT [r13+8], rax
    PRINT spaces, 7         ; padding
    PRINT pipe_sep, pipe_sep_l

    mov rsi, [r13 + 16]     ; Stock
    mov rdi, rsi
    call strlen
    PRINT [r13+16], rax

    PRINT newline, 1
    pop r13
    pop r12
    ret

; ================================================================
;  FUNCTION: sort_seller_by_price
;  Input:  rdi = 0 (low->high), 1 (high->low)
;  Bubble sort on price
; ================================================================
sort_seller:
    push r12
    push r13
    push r14
    push r15
    mov r15, rdi            ; sort direction

    mov r14, [num_sellers]  ; count

    ; fill sort_buf with [price_int, index] pairs
    xor r12, r12
.fill:
    cmp r12, r14
    jge .do_sort
    mov rax, r12
    imul rax, 24
    lea rbx, [sell_table + rax]
    mov rsi, [rbx + 8]      ; price string
    call str_to_int         ; rax = price int
    ; sort_buf[r12*2] = price, sort_buf[r12*2+1] = index
    mov rbx, r12
    imul rbx, 16
    lea rcx, [sort_buf + rbx]
    mov [rcx],   rax
    mov [rcx+8], r12
    inc r12
    jmp .fill

.do_sort:
    ; bubble sort
    mov r13, r14
    dec r13
.outer:
    test r13, r13
    jle .sort_done
    xor r12, r12
.inner:
    cmp r12, r13
    jge .inner_done

    mov rbx, r12
    imul rbx, 16
    lea rcx, [sort_buf + rbx]
    mov rax, [rcx]          ; price[i]
    mov rdx, [rcx + 16]     ; price[i+1]

    ; compare based on direction
    test r15, r15
    jnz .high_low_cmp

    ; low_high: swap if price[i] > price[i+1]
    cmp rax, rdx
    jle .no_swap
    jmp .do_swap

.high_low_cmp:
    ; high_low: swap if price[i] < price[i+1]
    cmp rax, rdx
    jge .no_swap

.do_swap:
    ; swap [rcx] and [rcx+16], [rcx+8] and [rcx+24]
    mov r8,  [rcx]
    mov r9,  [rcx+8]
    mov r10, [rcx+16]
    mov r11, [rcx+24]
    mov [rcx],    r10
    mov [rcx+8],  r11
    mov [rcx+16], r8
    mov [rcx+24], r9

.no_swap:
    inc r12
    jmp .inner
.inner_done:
    dec r13
    jmp .outer
.sort_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; ================================================================
;  FUNCTION: print_sorted_sellers
;  Input:  r15 = count
; ================================================================
print_sorted_sellers:
    push r12
    push r15
    call print_hdr_seller

    xor r12, r12
.loop:
    cmp r12, [num_sellers]
    jge .done
    ; get original index from sort_buf
    mov rbx, r12
    imul rbx, 16
    lea rcx, [sort_buf + rbx]
    ; r12 saved via push/pop below
    push r12
    mov r12, [rcx + 8]      ; original index
    call print_seller_row
    pop r12
    inc r12
    jmp .loop
.done:
    PRINT sep_line, sep_len
    pop r15
    pop r12
    ret

; ================================================================
;  FUNCTION: print_row_count
;  Input:  rax = count
; ================================================================
print_row_count:
    push rax
    PRINT msg_rows_found, msg_rows_found_l
    pop rax
    call int_to_str
    PRINT num_str_buf, r9
    PRINT newline, 1
    ret

; ================================================================
;  FUNCTION: read_line
;  Input:  rsi = buffer, rdx = max
;  Output: rax = bytes read
; ================================================================
read_line:
    push rsi
    push rdx
    mov rax, SYS_READ
    mov rdi, STDIN
    syscall
    ; strip newline
    test rax, rax
    jle .done
    push rax
    lea rbx, [rsi + rax - 1]
    mov cl, [rbx]
    cmp cl, 10
    jne .no_strip
    mov byte [rbx], 0
    dec rax
.no_strip:
    pop rax
.done:
    pop rdx
    pop rsi
    ret

; ================================================================
;  FUNCTION: skip_spaces
;  Input:  rsi = string pointer
;  Output: rsi = pointer after leading spaces
; ================================================================
skip_spaces:
.loop:
    mov al, [rsi]
    cmp al, ' '
    jne .done
    inc rsi
    jmp .loop
.done:
    ret

; ===============================================================
;  rest in peace my granny she got hit by bazooka kaboom kablow rest in peace
;  idkkkkk hhmm 

execute_query:
    push r12
    push r13
    push r14
    push r15

    ; ─── Check table ───
    cmp r14, 1
    je  .customers
    cmp r14, 2
    je  .seller
    PRINT err_unknown_table, err_unknown_table_l
    jmp .done

; ────────────────────────────────────────────
.customers:
    cmp r15, 1              ; Country + City
    je  .cust_cc
    cmp r15, 2              ; Name + Age
    je  .cust_na
    ; else all columns
    call print_hdr_all_customers
    xor r12, r12
.cust_all_loop:
    cmp r12, [num_customers]
    jge .cust_all_done
    call print_customer_row_all
    inc r12
    jmp .cust_all_loop
.cust_all_done:
    PRINT sep_line, sep_len
    mov rax, [num_customers]
    call print_row_count
    jmp .done

.cust_cc:
    call print_hdr_country_city
    xor r12, r12
.cust_cc_loop:
    cmp r12, [num_customers]
    jge .cust_cc_done
    call print_customer_row_cc
    inc r12
    jmp .cust_cc_loop
.cust_cc_done:
    PRINT sep_line, sep_len
    mov rax, [num_customers]
    call print_row_count
    jmp .done

.cust_na:
    call print_hdr_name_age
    xor r12, r12
.cust_na_loop:
    cmp r12, [num_customers]
    jge .cust_na_done
    call print_customer_row_na
    inc r12
    jmp .cust_na_loop
.cust_na_done:
    PRINT sep_line, sep_len
    mov rax, [num_customers]
    call print_row_count
    jmp .done

; ────────────────────────────────────────────
.seller:
    cmp rbx, 1              ; Low_high
    je  .sell_sorted_lh
    cmp rbx, 2              ; High_low
    je  .sell_sorted_hl
    ; no sort — print all
    call print_hdr_seller
    xor r12, r12
.sell_all_loop:
    cmp r12, [num_sellers]
    jge .sell_all_done
    call print_seller_row
    inc r12
    jmp .sell_all_loop
.sell_all_done:
    PRINT sep_line, sep_len
    mov rax, [num_sellers]
    call print_row_count
    jmp .done

.sell_sorted_lh:
    xor rdi, rdi            ; 0 = low to high
    call sort_seller
    call print_sorted_sellers
    mov rax, [num_sellers]
    call print_row_count
    jmp .done

.sell_sorted_hl:
    mov rdi, 1              ; 1 = high to low
    call sort_seller
    call print_sorted_sellers
    mov rax, [num_sellers]
    call print_row_count

.done:
    PRINT newline, 1
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; parser

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
.not_food:

    ; empty col spec = all columns (r15 stays 0)

.colspec_seller_check:
    call execute_query
    jmp .parse_done

.err_select:
    PRINT err_no_select, err_no_select_l
    jmp .parse_done
.err_from:
    PRINT err_no_from, err_no_from_l

.parse_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; ================================================================
;  MAIN LOOP
; ================================================================
_start:
    ; print banner
    PRINT banner, banner_len
    PRINT msg_help, msg_help_l

    ; init
    mov qword [last_table], 0

.main_loop:
    ; print prompt
    PRINT prompt, prompt_len

    ; read line
    lea rsi, [input_buf]
    mov rdx, 512
    call read_line

    ; check EOF
    test rax, rax
    jle .exit_clean

    ; check for exit/quit
    lea rsi, [input_buf]
    lea rdi, [kw_exit]
    call starts_with
    test rax, rax
    jz  .do_exit

    lea rsi, [input_buf]
    lea rdi, [kw_quit]
    call starts_with
    test rax, rax
    jz  .do_exit

    ; parse and run query
    call parse_and_run
    jmp .main_loop

.do_exit:
    mov rsi, input_buf
    ; print goodbye
    PRINT dbl_line, dbl_len

.exit_clean:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
