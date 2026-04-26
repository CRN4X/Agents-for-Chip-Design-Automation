
from pathlib import Path
root = Path('NVIDIA-ICLAD25-Hackathon-main/work')
empty=[]
nonempty=0
exists=0
for h in sorted(root.glob('*/harness/*')):
    if not h.is_dir():
        continue
    ro = h/'rtl.orig'
    if ro.exists() and ro.is_dir():
        exists += 1
        has_file = any(p.is_file() for p in ro.rglob('*'))
        if has_file:
            nonempty += 1
        else:
            empty.append(str(ro.relative_to(root)))
print(f'rtl_orig_exists={exists}')
print(f'rtl_orig_nonempty={nonempty}')
print(f'rtl_orig_empty={len(empty)}')
for p in empty:
    print(p)
