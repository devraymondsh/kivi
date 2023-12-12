const std = @import("std");

// C code:
// bool sse42_strcmp(const char *str1, const char *str2, size_t length, size_t ptr_cursor) {
//   __m128i a = _mm_loadu_si128((__m128i *)(str1 + ptr_cursor));
//   __m128i b = _mm_loadu_si128((__m128i *)(str2 + ptr_cursor));
//   return _mm_cmpestrc(a, length, b, length,
//                       _SIDD_CMP_EQUAL_EACH | _SIDD_NEGATIVE_POLARITY) == 0;
// }
comptime {
    asm (
        \\.intel_syntax noprefix
        \\sse42_strcmp:
        \\        movdqu  xmm0, xmmword ptr [rdi + rcx]
        \\        mov     eax, edx
        \\        pcmpestri       xmm0, xmmword ptr [rsi + rcx], 24
        \\        setae   al
        \\        ret
    );
}
extern fn sse42_strcmp(str1: [*]const u8, str2: [*]const u8, length: usize, ptr_cursor: usize) bool;

// C code:
// extern bool check_sse42_support() {
//   int cpuinfo[4];
//   __asm__ __volatile__("xchg %%ebx, %%edi;"
//                        "cpuid;"
//                        "xchg %%ebx, %%edi;"
//                        : "=a"(cpuinfo[0]), "=D"(cpuinfo[1]), "=c"(cpuinfo[2]),
//                          "=d"(cpuinfo[3])
//                        : "0"(1));

//   return cpuinfo[2] & (1 << 20) || false;
// }
comptime {
    asm (
        \\.intel_syntax noprefix
        \\check_sse42_support:
        \\        mov     eax, 1
        \\        xchg    edi, ebx
        \\        cpuid
        \\        xchg    edi, ebx
        \\        mov     eax, ecx
        \\        shr     eax, 20
        \\        and     eax, 1
        \\        ret
    );
}
pub extern fn check_sse42_support() bool;

pub fn strcmp(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }

    const previous_mul_16 = @as(usize, @intFromFloat(@floor(@as(f64, @floatFromInt(a.len / 16))) * 16));
    const remained = a.len - previous_mul_16;

    var prt_cursor: usize = 0;
    while (prt_cursor < previous_mul_16 and previous_mul_16 != 0) {
        if (!sse42_strcmp(a.ptr, b.ptr, 16, prt_cursor)) {
            return false;
        }

        prt_cursor += 16;
    }

    if (remained > 0) {
        if (!sse42_strcmp(a.ptr, b.ptr, remained, prt_cursor)) {
            return false;
        }
    }

    return true;
}

test "strcmp" {
    try std.testing.expect(strcmp("123", "123") == true);
    try std.testing.expect(strcmp("153", "123") == false);
    try std.testing.expect(strcmp("153", "1263") == false);
    try std.testing.expect(strcmp("1553", "123") == false);
    try std.testing.expect(strcmp("012345678912345", "012345678912345") == true);
    try std.testing.expect(strcmp("01234567F912345", "012345678912345") == false);
    try std.testing.expect(strcmp("0123456789123456", "0123456789123456") == true);
    try std.testing.expect(strcmp("01234567F9123456", "0123456789123456") == false);
    try std.testing.expect(strcmp("012345678912345678", "012345678912345678") == true);
    try std.testing.expect(strcmp("01234567F912345678", "012345678912345678") == false);
    try std.testing.expect(strcmp("cf0a4a13-a036-427d-bc67-982e094ce95f_Lionel Ankunding", "cf0a4a13-a036-427d-bc67-982e094ce95f_Lionel Ankunding") == true);
    try std.testing.expect(strcmp("cf0a4a13-a036-427d-bc67-<82e094ce95f_Lionel Ankunding", "cf0a4a13-a036-427d-bc67-982e094ce95f_Lionel Ankunding") == false);
}
