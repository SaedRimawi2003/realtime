    PROCESSOR 16F877A
    __CONFIG 0x3731

    INCLUDE "P16F877A.INC"

RS      EQU 1
E       EQU 2
Select  EQU 74
Temp    EQU 0x20
DelayCt EQU 0x21
DigitValue EQU 0x22      ; Current digit value for editing
Inactivity EQU 0x23
DigitPtr EQU 0x2A        ; Pointer to current digit variable

ClickCount EQU 0x2B      ; 1 = single, 2 = double
Section   EQU 0x2C       ; 0: integer, 1: decimal
DisplayState EQU 0x33    ; 0: Result, 1: Number 1, 2: Number 2

; Working variables for input (reused for both numbers)
Digit1  EQU 0x24
Digit2  EQU 0x25
Digit3  EQU 0x26
Digit4  EQU 0x27
Digit5  EQU 0x28
Digit6  EQU 0x29

Dec1    EQU 0x2D
Dec2    EQU 0x2E
Dec3    EQU 0x2F
Dec4    EQU 0x30
Dec5    EQU 0x31
Dec6    EQU 0x32

; Number 1 permanent storage (6 integer + 6 decimal)
Num1_Digit1  EQU 0x34
Num1_Digit2  EQU 0x35
Num1_Digit3  EQU 0x36
Num1_Digit4  EQU 0x37
Num1_Digit5  EQU 0x38
Num1_Digit6  EQU 0x39

Num1_Dec1    EQU 0x3A
Num1_Dec2    EQU 0x3B
Num1_Dec3    EQU 0x3C
Num1_Dec4    EQU 0x3D
Num1_Dec5    EQU 0x3E
Num1_Dec6    EQU 0x3F

; Number 2 storage (6 integer + 6 decimal)
Num2_Digit1  EQU 0x40
Num2_Digit2  EQU 0x41
Num2_Digit3  EQU 0x42
Num2_Digit4  EQU 0x43
Num2_Digit5  EQU 0x44
Num2_Digit6  EQU 0x45

Num2_Dec1    EQU 0x46
Num2_Dec2    EQU 0x47
Num2_Dec3    EQU 0x48
Num2_Dec4    EQU 0x49
Num2_Dec5    EQU 0x4A
Num2_Dec6    EQU 0x4B

    ORG 0
    NOP

    ;--- Set TRISD and TRISB using BANKSEL (no Message[302]) ---
    BANKSEL TRISD
    MOVLW 0x00
    MOVWF TRISD        ; Set PORTD as output

    BANKSEL TRISB
    MOVLW 0x01         ; Set RB0 as input, others output
    MOVWF TRISB

    BANKSEL PORTD      ; Return to bank 0

    ; Init LCD
    CALL inid

    ; Blink welcome as before
    MOVLW D'3'
    MOVWF Temp
blink_loop
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_welcome

    MOVLW 0xC0
    BCF Select, RS
    CALL send
    CALL print_division

    CALL delay_250ms
    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_250ms
    DECFSZ Temp, f
    GOTO blink_loop

    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_1s

; --------- Main Program Entry Point ---------
main_program_start:
    ; Clear all stored numbers at the beginning
    CALL clear_all_numbers

; --------- Number 1 Entry ---------
start_number1:
    ; Show Number 1
    MOVLW 0x01
    BCF Select, RS
    CALL send
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number1

    ; --- Initialize all digits to zero ---
    CLRF Digit1
    CLRF Digit2
    CLRF Digit3
    CLRF Digit4
    CLRF Digit5
    CLRF Digit6
    CLRF Dec1
    CLRF Dec2
    CLRF Dec3
    CLRF Dec4
    CLRF Dec5
    CLRF Dec6

    ; --- Initial LCD display: 000000.000000 ---
    CALL display_all_digits

    ; --- Multi-digit entry: integer then decimal ---
    CLRF Section        ; 0 = integer, 1 = decimal

start_entry1:
    MOVLW Digit1
    MOVWF DigitPtr      ; Start with integer part

    MOVLW 6
    MOVWF Temp          ; 6 digits to enter

    CLRF DigitValue     ; Start with 0 for first digit

    ; === First integer digit special logic ===
first_digit_entry1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section1

first_digit_handle_press1:
wait_release1
    BTFSS PORTB, 0
    GOTO wait_release1
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_digit_entry1
    CLRF DigitValue
    GOTO first_digit_entry1

first_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO first_digit_input_loop1

    ; Inactivity: fill all digits with first digit value
    MOVF DigitValue, W
    MOVWF Digit1
    MOVWF Digit2
    MOVWF Digit3
    MOVWF Digit4
    MOVWF Digit5
    MOVWF Digit6

    ; Now move to second digit for further editing
    MOVLW Digit2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp          ; 5 digits left

    GOTO edit_next_digit1

; === Remainder of integer digits: normal per-digit editing ===
edit_next_digit1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_digit1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section1

edit_digit_handle_press1:
wait_release2
    BTFSS PORTB, 0
    GOTO wait_release2
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_digit1
    CLRF DigitValue
    GOTO edit_this_digit1

edit_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO edit_digit_input_loop1

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_digit1

    ; All integer digits entered, start decimal part
    GOTO start_decimal_section1

; === Decimal part: same logic ===
start_decimal_section1:
    MOVLW 1
    MOVWF Section
    MOVLW Dec1
    MOVWF DigitPtr      ; Start decimal digits

    MOVLW 6
    MOVWF Temp          ; 6 decimal digits

    CLRF DigitValue     ; Start with 0 for first decimal

    ; Special logic for first decimal digit (fill all on inactivity)
first_decimal_digit_entry1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_dec_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number1

first_dec_digit_handle_press1:
wait_release3
    BTFSS PORTB, 0
    GOTO wait_release3
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_decimal_digit_entry1
    CLRF DigitValue
    GOTO first_decimal_digit_entry1

first_dec_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO first_dec_digit_input_loop1

    ; Inactivity: fill all decimal digits with first decimal value
    MOVF DigitValue, W
    MOVWF Dec1
    MOVWF Dec2
    MOVWF Dec3
    MOVWF Dec4
    MOVWF Dec5
    MOVWF Dec6

    ; Now move to second decimal digit for further editing
    MOVLW Dec2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp          ; 5 decimal digits left

    GOTO edit_next_dec_digit1

; === Remainder of decimals: normal per-digit editing ===
edit_next_dec_digit1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_dec_digit1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_dec_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number1

edit_dec_digit_handle_press1:
wait_release4
    BTFSS PORTB, 0
    GOTO wait_release4
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_dec_digit1
    CLRF DigitValue
    GOTO edit_this_dec_digit1

edit_dec_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO edit_dec_digit_input_loop1

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_dec_digit1

finish_number1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    ; Save Number 1 to permanent storage before proceeding to Number 2
    CALL save_number1

    CALL display_all_digits
    CALL delay_1s

; --------- Number 2 Entry ---------
start_number2:
    ; Clear LCD
    MOVLW 0x01
    BCF Select, RS
    CALL send

    ; Print "Number 2" on line 1
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number2

    ; Clear working digits for number 2 entry
    CLRF Digit1
    CLRF Digit2
    CLRF Digit3
    CLRF Digit4
    CLRF Digit5
    CLRF Digit6
    CLRF Dec1
    CLRF Dec2
    CLRF Dec3
    CLRF Dec4
    CLRF Dec5
    CLRF Dec6

    ; Print 000000.000000 for Number 2
    CALL display_all_digits

    ; --- Multi-digit entry for number 2 (identical to number 1 logic) ---
    CLRF Section        ; 0 = integer, 1 = decimal

start_entry2:
    MOVLW Digit1
    MOVWF DigitPtr      ; Start with integer part

    MOVLW 6
    MOVWF Temp          ; 6 digits to enter

    CLRF DigitValue     ; Start with 0 for first digit

first_digit_entry2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section2

first_digit_handle_press2:
wait_release12
    BTFSS PORTB, 0
    GOTO wait_release12
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_digit_entry2
    CLRF DigitValue
    GOTO first_digit_entry2

first_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO first_digit_input_loop2

    MOVF DigitValue, W
    MOVWF Digit1
    MOVWF Digit2
    MOVWF Digit3
    MOVWF Digit4
    MOVWF Digit5
    MOVWF Digit6

    MOVLW Digit2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp

    GOTO edit_next_digit2

edit_next_digit2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_digit2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section2

edit_digit_handle_press2:
wait_release22
    BTFSS PORTB, 0
    GOTO wait_release22
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_digit2
    CLRF DigitValue
    GOTO edit_this_digit2

edit_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO edit_digit_input_loop2

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_digit2

    GOTO start_decimal_section2

start_decimal_section2:
    MOVLW 1
    MOVWF Section
    MOVLW Dec1
    MOVWF DigitPtr

    MOVLW 6
    MOVWF Temp

    CLRF DigitValue

first_decimal_digit_entry2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_dec_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number2

first_dec_digit_handle_press2:
wait_release32
    BTFSS PORTB, 0
    GOTO wait_release32
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_decimal_digit_entry2
    CLRF DigitValue
    GOTO first_decimal_digit_entry2

first_dec_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO first_dec_digit_input_loop2

    MOVF DigitValue, W
    MOVWF Dec1
    MOVWF Dec2
    MOVWF Dec3
    MOVWF Dec4
    MOVWF Dec5
    MOVWF Dec6

    MOVLW Dec2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp

    GOTO edit_next_dec_digit2

edit_next_dec_digit2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_dec_digit2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_dec_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number2

edit_dec_digit_handle_press2:
wait_release42
    BTFSS PORTB, 0
    GOTO wait_release42
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_dec_digit2
    CLRF DigitValue
    GOTO edit_this_dec_digit2

edit_dec_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'4'              ; 4*250ms = 1 second (changed from 12 = 3 seconds)
    BTFSS STATUS, Z
    GOTO edit_dec_digit_input_loop2

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_dec_digit2

finish_number2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    ; Save Number 2 to permanent storage
    CALL save_number2

    CALL display_all_digits
    CALL delay_1s

    ; *** KEY CHANGE: Immediately show Result first, then start cycling ***
    ; Start display cycling mode with Result (DisplayState = 0)
    CLRF DisplayState    ; Start with Result (0)
    GOTO display_cycle_mode

;--------------------------------------------------------
; Clear all stored numbers (Number 1 and Number 2)
clear_all_numbers:
    ; Clear Number 1 storage
    CLRF Num1_Digit1
    CLRF Num1_Digit2
    CLRF Num1_Digit3
    CLRF Num1_Digit4
    CLRF Num1_Digit5
    CLRF Num1_Digit6
    CLRF Num1_Dec1
    CLRF Num1_Dec2
    CLRF Num1_Dec3
    CLRF Num1_Dec4
    CLRF Num1_Dec5
    CLRF Num1_Dec6
    
    ; Clear Number 2 storage
    CLRF Num2_Digit1
    CLRF Num2_Digit2
    CLRF Num2_Digit3
    CLRF Num2_Digit4
    CLRF Num2_Digit5
    CLRF Num2_Digit6
    CLRF Num2_Dec1
    CLRF Num2_Dec2
    CLRF Num2_Dec3
    CLRF Num2_Dec4
    CLRF Num2_Dec5
    CLRF Num2_Dec6
    RETURN

;--------------------------------------------------------
; Save Number 1 from working storage (Digit1..Digit6, Dec1..Dec6) to permanent storage
save_number1:
    MOVF Digit1, W
    MOVWF Num1_Digit1
    MOVF Digit2, W
    MOVWF Num1_Digit2
    MOVF Digit3, W
    MOVWF Num1_Digit3
    MOVF Digit4, W
    MOVWF Num1_Digit4
    MOVF Digit5, W
    MOVWF Num1_Digit5
    MOVF Digit6, W
    MOVWF Num1_Digit6
    
    MOVF Dec1, W
    MOVWF Num1_Dec1
    MOVF Dec2, W
    MOVWF Num1_Dec2
    MOVF Dec3, W
    MOVWF Num1_Dec3
    MOVF Dec4, W
    MOVWF Num1_Dec4
    MOVF Dec5, W
    MOVWF Num1_Dec5
    MOVF Dec6, W
    MOVWF Num1_Dec6
    RETURN

;--------------------------------------------------------
; Save Number 2 from working storage (Digit1..Digit6, Dec1..Dec6) to permanent storage
save_number2:
    MOVF Digit1, W
    MOVWF Num2_Digit1
    MOVF Digit2, W
    MOVWF Num2_Digit2
    MOVF Digit3, W
    MOVWF Num2_Digit3
    MOVF Digit4, W
    MOVWF Num2_Digit4
    MOVF Digit5, W
    MOVWF Num2_Digit5
    MOVF Digit6, W
    MOVWF Num2_Digit6
    
    MOVF Dec1, W
    MOVWF Num2_Dec1
    MOVF Dec2, W
    MOVWF Num2_Dec2
    MOVF Dec3, W
    MOVWF Num2_Dec3
    MOVF Dec4, W
    MOVWF Num2_Dec4
    MOVF Dec5, W
    MOVWF Num2_Dec5
    MOVF Dec6, W
    MOVWF Num2_Dec6
    RETURN

;--------------------------------------------------------
; Display cycling mode: Result ? Number 1 ? Number 2 ? Result...
display_cycle_mode:
    ; Display current state
    CALL display_current_state
    
    ; Wait for button press
cycle_wait_input:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO cycle_wait_input    ; Timeout, keep waiting
    
    ; Check for double-click (restart entire process)
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO restart_entire_process
    
    ; Single click - cycle to next state
    INCF DisplayState, F
    MOVF DisplayState, W
    SUBLW 3
    BTFSC STATUS, Z
    CLRF DisplayState        ; Wrap around to 0 after state 2
    
    GOTO display_cycle_mode

;--------------------------------------------------------
; Display the current state based on DisplayState variable
; DisplayState: 0=Result, 1=Number1, 2=Number2
display_current_state:
    MOVF DisplayState, W
    BTFSC STATUS, Z
    GOTO display_state_result    ; DisplayState = 0
    DECF DisplayState, W
    BTFSC STATUS, Z
    GOTO display_state_number1   ; DisplayState = 1
    GOTO display_state_number2   ; DisplayState = 2

display_state_result:
    ; Display Result
    MOVLW 0x01
    BCF Select, RS
    CALL send
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_result
    
    ; Load Result data (all zeros) into display variables and show
    CALL load_result_for_display
    CALL display_all_digits
    RETURN

display_state_number1:
    ; Display Number 1
    MOVLW 0x01
    BCF Select, RS
    CALL send
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number1
    
    ; Load Number 1 data into display variables and show
    CALL load_number1_for_display
    CALL display_all_digits
    RETURN

display_state_number2:
    ; Display Number 2
    MOVLW 0x01
    BCF Select, RS
    CALL send
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number2
    
    ; Load Number 2 data into display variables and show
    CALL load_number2_for_display
    CALL display_all_digits
    RETURN

;--------------------------------------------------------
; Load Number 1 into display variables (Digit1..Digit6, Dec1..Dec6)
load_number1_for_display:
    MOVF Num1_Digit1, W
    MOVWF Digit1
    MOVF Num1_Digit2, W
    MOVWF Digit2
    MOVF Num1_Digit3, W
    MOVWF Digit3
    MOVF Num1_Digit4, W
    MOVWF Digit4
    MOVF Num1_Digit5, W
    MOVWF Digit5
    MOVF Num1_Digit6, W
    MOVWF Digit6
    
    MOVF Num1_Dec1, W
    MOVWF Dec1
    MOVF Num1_Dec2, W
    MOVWF Dec2
    MOVF Num1_Dec3, W
    MOVWF Dec3
    MOVF Num1_Dec4, W
    MOVWF Dec4
    MOVF Num1_Dec5, W
    MOVWF Dec5
    MOVF Num1_Dec6, W
    MOVWF Dec6
    RETURN

;--------------------------------------------------------
; Load Number 2 into display variables
load_number2_for_display:
    MOVF Num2_Digit1, W
    MOVWF Digit1
    MOVF Num2_Digit2, W
    MOVWF Digit2
    MOVF Num2_Digit3, W
    MOVWF Digit3
    MOVF Num2_Digit4, W
    MOVWF Digit4
    MOVF Num2_Digit5, W
    MOVWF Digit5
    MOVF Num2_Digit6, W
    MOVWF Digit6
    
    MOVF Num2_Dec1, W
    MOVWF Dec1
    MOVF Num2_Dec2, W
    MOVWF Dec2
    MOVF Num2_Dec3, W
    MOVWF Dec3
    MOVF Num2_Dec4, W
    MOVWF Dec4
    MOVF Num2_Dec5, W
    MOVWF Dec5
    MOVF Num2_Dec6, W
    MOVWF Dec6
    RETURN

;--------------------------------------------------------
; Load Result (all zeros) into display variables
load_result_for_display:
    CLRF Digit1
    CLRF Digit2
    CLRF Digit3
    CLRF Digit4
    CLRF Digit5
    CLRF Digit6
    
    CLRF Dec1
    CLRF Dec2
    CLRF Dec3
    CLRF Dec4
    CLRF Dec5
    CLRF Dec6
    RETURN

;--------------------------------------------------------
; Restart the entire process - this is the key fix!
restart_entire_process:
    ; Clear LCD
    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_250ms
    
    ; Go back to the main program start to clear all numbers and restart
    GOTO main_program_start

;--------------------------------------------------------
; Wait for click or timeout, sets ClickCount: 0=timeout, 1=single, 2=double
wait_click_or_timeout
    CLRF ClickCount
    MOVLW D'12'
    MOVWF DelayCt
wait_click_loop
    MOVLW D'10'
    CALL xms
    BTFSS PORTB, 0
    GOTO first_click
    DECFSZ DelayCt,F
    GOTO wait_click_loop
    RETURN          ; Timeout, ClickCount=0

first_click:
    INCF ClickCount,F
    ; Wait for release (debounce)
wait_release_btn
    BTFSS PORTB,0
    GOTO wait_release_btn
    MOVLW D'15'
    CALL xms

    ; Wait short period for double click
    MOVLW D'25'
    MOVWF DelayCt
wait_double_time
    MOVLW D'10'
    CALL xms
    BTFSS PORTB,0
    GOTO second_click
    DECFSZ DelayCt,F
    GOTO wait_double_time
    RETURN          ; Single tap, ClickCount=1

second_click:
    INCF ClickCount,F
    ; Wait for release again
wait_release_btn2
    BTFSS PORTB,0
    GOTO wait_release_btn2
    MOVLW D'15'
    CALL xms
    RETURN          ; Double tap, ClickCount=2

;--------------------------------------------------------
display_all_digits
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    MOVF Digit1, W
    ADDLW '0'
    CALL send
    MOVF Digit2, W
    ADDLW '0'
    CALL send
    MOVF Digit3, W
    ADDLW '0'
    CALL send
    MOVF Digit4, W
    ADDLW '0'
    CALL send
    MOVF Digit5, W
    ADDLW '0'
    CALL send
    MOVF Digit6, W
    ADDLW '0'
    CALL send
    MOVLW '.'
    CALL send
    MOVF Dec1, W
    ADDLW '0'
    CALL send
    MOVF Dec2, W
    ADDLW '0'
    CALL send
    MOVF Dec3, W
    ADDLW '0'
    CALL send
    MOVF Dec4, W
    ADDLW '0'
    CALL send
    MOVF Dec5, W
    ADDLW '0'
    CALL send
    MOVF Dec6, W
    ADDLW '0'
    CALL send
    RETURN

display_all_digits_with_cursor
    ; Shows all digits with the one being edited as DigitValue
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS

    MOVLW Digit1
    MOVWF FSR
    MOVLW 6
    MOVWF DelayCt

show_digits_loop:
    MOVF FSR, W
    MOVWF Temp
    MOVF DigitPtr, W
    SUBWF Temp, W
    BTFSS STATUS, Z
    GOTO show_digit_from_mem
    ; Current digit: show DigitValue
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
    GOTO after_digit
show_digit_from_mem:
    MOVF INDF, W
    ADDLW '0'
    CALL send
after_digit:
    INCF FSR, F
    DECFSZ DelayCt, f
    GOTO show_digits_loop

    ; Decimal dot
    MOVLW '.'
    CALL send

    ; Now decimals
    MOVLW Dec1
    MOVWF FSR
    MOVLW 6
    MOVWF DelayCt

show_decs_loop:
    MOVF FSR, W
    MOVWF Temp
    MOVF DigitPtr, W
    SUBWF Temp, W
    BTFSS STATUS, Z
    GOTO show_dec_from_mem
    ; Current digit: show DigitValue
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
    GOTO after_dec
show_dec_from_mem:
    MOVF INDF, W
    ADDLW '0'
    CALL send
after_dec:
    INCF FSR, F
    DECFSZ DelayCt, f
    GOTO show_decs_loop
    RETURN

;--------------------------------------------------------
print_welcome
    BSF Select, RS
    MOVLW 'W'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'L'
    CALL send
    MOVLW 'C'
    CALL send
    MOVLW 'O'
    CALL send
    MOVLW 'M'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'T'
    CALL send
    MOVLW 'O'
    CALL send
    RETURN

print_division
    BSF Select, RS
    MOVLW 'D'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'V'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'S'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'O'
    CALL send
    MOVLW 'N'
    CALL send
    RETURN

print_number1
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'm'
    CALL send
    MOVLW 'b'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 'r'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW '1'
    CALL send
    RETURN

print_number2
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'm'
    CALL send
    MOVLW 'b'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 'r'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW '2'
    CALL send
    RETURN

print_result
    BSF Select, RS
    MOVLW 'R'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 's'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'l'
    CALL send
    MOVLW 't'
    CALL send
    RETURN

delay_250ms
    MOVLW D'2'
    MOVWF DelayCt
d250_loop
    MOVLW D'250'
    CALL xms
    DECFSZ DelayCt, f
    GOTO d250_loop
    RETURN

delay_1s
    MOVLW D'4'
    MOVWF DelayCt
d1s_loop
    MOVLW D'250'
    CALL xms
    DECFSZ DelayCt, f
    GOTO d1s_loop
    RETURN

    INCLUDE "LCDIS.INC"

    END