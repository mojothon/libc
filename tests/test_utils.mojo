from libc.utils import string_to_char_ptr, char_ptr_to_string, strlen, CString


fn main():
    var s = "Hello, World!"

    var s1 = string_to_char_ptr(s)  
    print(s1)
    print(strlen(s1))

    print(char_ptr_to_string(string_to_char_ptr(s)))

    var data = CString(s1)

    print(str(data))

