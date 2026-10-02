"""Regenerate the checked-in RV64C oracle using GNU RISC-V binutils."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


def generate():
    pairs = []
    def add(c, base):
        pairs.append((c, base))
    for rd in (1, 8, 15, 31):
        for n in (-32, -1, 0, 1, 31):
            for op in ('addi', 'addiw'):
                add(f'c.{op} x{rd},{n}', f'{op} x{rd},x{rd},{n}')
            add(f'c.li x{rd},{n}', f'addi x{rd},x0,{n}')
        for n in (1, 31, 32, 63):
            add(f'c.slli x{rd},{n}', f'slli x{rd},x{rd},{n}')
        for rs in (1, 8, 31):
            add(f'c.mv x{rd},x{rs}', f'add x{rd},x0,x{rs}')
            add(f'c.add x{rd},x{rs}', f'add x{rd},x{rd},x{rs}')
        add(f'c.jr x{rd}', f'jalr x0,0(x{rd})')
        add(f'c.jalr x{rd}', f'jalr x1,0(x{rd})')
        for op, step, maximum in [('lw', 4, 252), ('ld', 8, 504)]:
            for n in (0, step, maximum):
                add(f'c.{op}sp x{rd},{n}(sp)', f'{op} x{rd},{n}(sp)')
        for op, step, maximum in [('sw', 4, 252), ('sd', 8, 504)]:
            for n in (0, step, maximum):
                add(f'c.{op}sp x{rd},{n}(sp)', f'{op} x{rd},{n}(sp)')
        for n in (1, 31, 0xfffff):
            add(f'c.lui x{rd},{n}', f'lui x{rd},{n}')
    for rd in (8, 15):
        for n in (4, 16, 64, 256, 1020):
            add(f'c.addi4spn x{rd},sp,{n}', f'addi x{rd},sp,{n}')
        for n in (1, 31, 32, 63):
            for op in ('srli', 'srai'):
                add(f'c.{op} x{rd},{n}', f'{op} x{rd},x{rd},{n}')
        for n in (-32, -1, 0, 31):
            add(f'c.andi x{rd},{n}', f'andi x{rd},x{rd},{n}')
        for rs in (8, 15):
            for op in ('sub', 'xor', 'or', 'and', 'subw', 'addw'):
                add(f'c.{op} x{rd},x{rs}', f'{op} x{rd},x{rd},x{rs}')
            for op, step, maximum in [('lw', 4, 124), ('sw', 4, 124), ('ld', 8, 248), ('sd', 8, 248)]:
                for n in (0, step, maximum):
                    add(f'c.{op} x{rd},{n}(x{rs})', f'{op} x{rd},{n}(x{rs})')
        for n in (-256, -2, 0, 2, 254):
            for op in ('beq', 'bne'):
                add(f'c.{op}z x{rd},.+({n})', f'{op} x{rd},x0,.+({n})')
    for n in (-512, -16, 16, 496):
        add(f'c.addi16sp sp,{n}', f'addi sp,sp,{n}')
    for n in (-2048, -2, 0, 2, 2046):
        add(f'c.j .+({n})', f'jal x0,.+({n})')
    add('c.ebreak', 'ebreak')
    add('c.nop', 'addi x0,x0,0')
    prefix = os.environ.get('RISCV_PREFIX', 'riscv-none-elf-')
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        source = '.text\n.option norelax\n' + '\n'.join(
            f'.option rvc\n{c}\n.option norvc\n{base}' for c, base in pairs)
        (root / 'vectors.S').write_text(source+'\n')
        subprocess.run([prefix+'as', '-march=rv64ic', '-o', str(root/'vectors.o'), str(root/'vectors.S')], check=True)
        subprocess.run([prefix+'ld', '-m', 'elf64lriscv', '-e', '0', '-Ttext=0', '--no-relax', '-o', str(root/'vectors.elf'), str(root/'vectors.o')], check=True)
        subprocess.run([prefix+'objcopy', '-O', 'binary', '-j', '.text', str(root/'vectors.elf'), str(root/'vectors.bin')], check=True)
        data = (root/'vectors.bin').read_bytes()
    assert len(data) == len(pairs)*6
    vectors = [[c, data[i*6:i*6+2].hex(), data[i*6+2:i*6+6].hex()] for i, (c, _) in enumerate(pairs)]
    Path(__file__).with_name('vectors.json').write_text(json.dumps(vectors, indent=2)+'\n')

if __name__ == '__main__':
    generate()
