BITS 16
section .text
foo:
add eax, [ecx]
add eax, [ebp]
add eax, [esp]
add eax, [dword 100]
add eax, [dword 1600]
add eax, [ecx*1]
add eax, [ecx*2]
add eax, [ecx*4]
add eax, [ecx*8]
add eax, [ebp*1]
add eax, [ebp*2]
add eax, [ebp*4]
add eax, [ebp*8]
add eax, [184+ecx]
add eax, [dword 1600+ecx]
add eax, [100+ebp]
add eax, [dword 1600+ebp]
add eax, [184+esp]
add eax, [dword 1600+esp]
add eax, [100+ecx]
add eax, [dword 1600+ecx]
add eax, [184+ebp]
add eax, [dword 1600+ebp]
add eax, [184+esp]
add eax, [dword 1600+esp]
add eax, [ecx+edx*1]
add eax, [ebp*1+ecx]
add eax, [ecx+edx*2]
add eax, [ebp*2+ecx]
add eax, [ecx+edx*4]
add eax, [ebp*4+ecx]
add eax, [ecx+edx*8]
add eax, [ecx+ebp*8]
add eax, [edx*1+ebp]
add eax, [ebp+ebp*1]
add eax, [ebp+edx*2]
add eax, [ebp+ebp*2]
add eax, [ebp+edx*4]
add eax, [ebp*4+ebp]
add eax, [ebp+edx*8]
add eax, [ebp+ebp*8]
add eax, [esp+edx*1]
add eax, [esp+ebp*1]
add eax, [esp+edx*2]
add eax, [ebp*2+esp]
add eax, [esp+edx*4]
add eax, [esp+ebp*4]
add eax, [esp+edx*8]
add eax, [esp+ebp*8]
add eax, [100+ecx*1]
add eax, [184+ecx*2]
add eax, [100+ecx*4]
add eax, [184+ecx*8]
add eax, [100+ebp*1]
add eax, [184+ebp*2]
add eax, [100+ebp*4]
add eax, [184+ebp*8]
add eax, [dword 1600+ecx*1]
add eax, [dword 1600+ecx*2]
add eax, [dword 1600+ecx*4]
add eax, [dword 1600+ecx*8]
add eax, [dword 1600+ebp*1]
add eax, [dword 1600+ebp*2]
add eax, [dword 1600+ebp*4]
add eax, [dword 1600+ebp*8]
add eax, [100+ecx+edx*1]
add eax, [184+ecx+edx*2]
add eax, [100+edx*4+ecx]
add eax, [184+ecx+edx*8]
add eax, [100+ecx+ebp*1]
add eax, [184+ecx+ebp*2]
add eax, [100+ecx+ebp*4]
add eax, [184+ecx+ebp*8]
add eax, [100+ebp+edx*1]
add eax, [184+ebp+edx*2]
add eax, [100+ebp+edx*4]
add eax, [184+ebp+edx*8]
add eax, [100+ebp+ebp*1]
add eax, [184+ebp*2+ebp]
add eax, [100+ebp+ebp*4]
add eax, [184+ebp+ebp*8]
add eax, [100+esp+edx*1]
add eax, [184+esp+edx*2]
add eax, [100+esp+edx*4]
add eax, [184+esp+edx*8]
add eax, [100+esp+ebp*1]
add eax, [184+esp+ebp*2]
add eax, [100+esp+ebp*4]
add eax, [184+esp+ebp*8]
add eax, [dword 1600+ecx+edx*1]
add eax, [dword 1600+ecx+edx*2]
add eax, [dword 1600+ecx+edx*4]
add eax, [dword 1600+ecx+edx*8]
add eax, [dword 1600+ecx+ebp*1]
add eax, [dword 1600+ecx+ebp*2]
add eax, [dword 1600+ecx+ebp*4]
add eax, [dword 1600+ecx+ebp*8]
add eax, [dword 1600+ebp+edx*1]
add eax, [dword 1600+ebp+edx*2]
add eax, [dword 1600+ebp+edx*4]
add eax, [dword 1600+ebp+edx*8]
add eax, [dword 1600+ebp+ebp*1]
add eax, [dword 1600+ebp+ebp*2]
add eax, [dword 1600+ebp+ebp*4]
add eax, [dword 1600+ebp+ebp*8]
add eax, [dword 1600+esp+edx*1]
add eax, [dword 1600+esp+edx*2]
add eax, [dword 1600+esp+edx*4]
add eax, [dword 1600+esp+edx*8]
add eax, [dword 1600+esp+ebp*1]
add eax, [dword 1600+esp+ebp*2]
add eax, [dword 1600+esp+ebp*4]
add eax, [dword 1600+esp+ebp*8]
